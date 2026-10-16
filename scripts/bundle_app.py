#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
import re

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BUILD_DIR = os.path.join(ROOT_DIR, "build")
APP_BUNDLE = os.path.join(BUILD_DIR, "DroidMirror.app")
CONTENTS_DIR = os.path.join(APP_BUNDLE, "Contents")
MACOS_DIR = os.path.join(CONTENTS_DIR, "MacOS")
RESOURCES_DIR = os.path.join(CONTENTS_DIR, "Resources")
BIN_DIR = os.path.join(RESOURCES_DIR, "bin")
FRAMEWORKS_DIR = os.path.join(CONTENTS_DIR, "Frameworks")
CACHE_DIR = os.path.join(BUILD_DIR, "cache")

def run(cmd, cwd=ROOT_DIR):
    print(f"==> Running: {' '.join(cmd)}")
    res = subprocess.run(cmd, cwd=cwd)
    if res.returncode != 0:
        print(f"Error running command (exit {res.returncode}): {' '.join(cmd)}")
        sys.exit(res.returncode)

def get_dependencies(binary_path):
    try:
        out = subprocess.check_output(["otool", "-L", binary_path]).decode("utf-8")
    except Exception as e:
        print(f"Warning: could not otool -L {binary_path}: {e}")
        return []

    deps = []
    for line in out.strip().split("\n")[1:]:
        m = re.match(r"^\s*([^\s]+)", line)
        if m:
            dep = m.group(1)
            # Skip macOS system libraries
            if not dep.startswith("/usr/lib") and not dep.startswith("/System/Library"):
                deps.append(dep)
    return deps

def main():
    print("--- 1. Cleaning & preparing build folders ---")
    if os.path.exists(BUILD_DIR):
        shutil.rmtree(BUILD_DIR)

    os.makedirs(MACOS_DIR, exist_ok=True)
    os.makedirs(BIN_DIR, exist_ok=True)
    os.makedirs(FRAMEWORKS_DIR, exist_ok=True)
    os.makedirs(CACHE_DIR, exist_ok=True)

    print("--- 2. Compiling Swift GUI App ---")
    swift_sources = [
        os.path.join(ROOT_DIR, "Sources/Models/Device.swift"),
        os.path.join(ROOT_DIR, "Sources/Services/BinaryResolver.swift"),
        os.path.join(ROOT_DIR, "Sources/Services/ProcessRunner.swift"),
        os.path.join(ROOT_DIR, "Sources/Services/ADBService.swift"),
        os.path.join(ROOT_DIR, "Sources/Services/ScrcpyService.swift"),
        os.path.join(ROOT_DIR, "Sources/Views/LogDrawerView.swift"),
        os.path.join(ROOT_DIR, "Sources/Views/WirelessConnectSheet.swift"),
        os.path.join(ROOT_DIR, "Sources/Views/EmptyStateGuideView.swift"),
        os.path.join(ROOT_DIR, "Sources/Views/DeviceDetailView.swift"),
        os.path.join(ROOT_DIR, "Sources/Views/ContentView.swift"),
        os.path.join(ROOT_DIR, "Sources/App.swift"),
    ]

    exec_path = os.path.join(MACOS_DIR, "DroidMirror")
    compile_cmd = [
        "swiftc",
        "-O",
        "-parse-as-library",
        "-module-cache-path", CACHE_DIR,
        *swift_sources,
        "-o", exec_path
    ]
    run(compile_cmd)

    print("--- 3. Copying Info.plist ---")
    shutil.copy2(os.path.join(ROOT_DIR, "Resources/Info.plist"), os.path.join(CONTENTS_DIR, "Info.plist"))

    print("--- 4. Locating & Copying ADB and Scrcpy ---")
    adb_src = shutil.which("adb") or "/opt/homebrew/bin/adb"
    scrcpy_src = shutil.which("scrcpy") or "/opt/homebrew/bin/scrcpy"
    
    server_candidates = [
        "/opt/homebrew/share/scrcpy/scrcpy-server",
        "/opt/homebrew/Cellar/scrcpy/4.1_1/share/scrcpy/scrcpy-server"
    ]
    scrcpy_server_src = next((s for s in server_candidates if os.path.exists(s)), None)

    if not os.path.exists(adb_src):
        print(f"Error: adb not found at {adb_src}")
        sys.exit(1)
    if not os.path.exists(scrcpy_src):
        print(f"Error: scrcpy not found at {scrcpy_src}")
        sys.exit(1)
    if not scrcpy_server_src or not os.path.exists(scrcpy_server_src):
        print(f"Error: scrcpy-server not found!")
        sys.exit(1)

    bundled_adb = os.path.join(BIN_DIR, "adb")
    bundled_scrcpy = os.path.join(BIN_DIR, "scrcpy")
    bundled_server = os.path.join(BIN_DIR, "scrcpy-server")

    shutil.copy2(adb_src, bundled_adb)
    shutil.copy2(scrcpy_src, bundled_scrcpy)
    shutil.copy2(scrcpy_server_src, bundled_server)

    os.chmod(bundled_adb, 0o755)
    os.chmod(bundled_scrcpy, 0o755)
    os.chmod(bundled_server, 0o644)

    print("--- 5. Collecting all dynamic libraries for scrcpy ---")
    visited_files = set()
    queue = [bundled_scrcpy]
    copied_frameworks = {}

    while queue:
        curr = queue.pop(0)
        deps = get_dependencies(curr)
        for dep in deps:
            real_dep = os.path.realpath(dep)
            base = os.path.basename(real_dep)
            target = os.path.join(FRAMEWORKS_DIR, base)

            if real_dep not in visited_files:
                visited_files.add(real_dep)
                if not os.path.exists(target):
                    shutil.copy2(real_dep, target)
                    os.chmod(target, 0o755)
                copied_frameworks[dep] = target
                copied_frameworks[real_dep] = target
                queue.append(target)

    print(f"Collected {len(visited_files)} dynamic libraries into Contents/Frameworks/")

    print("--- 6. Re-linking library paths via install_name_tool ---")
    # Add @rpath to scrcpy binary
    subprocess.run(["install_name_tool", "-add_rpath", "@executable_path/../../Frameworks", bundled_scrcpy], check=False)
    subprocess.run(["install_name_tool", "-add_rpath", "@loader_path/../../Frameworks", bundled_scrcpy], check=False)

    # Re-link scrcpy dependencies
    for original_path, target_dylib in copied_frameworks.items():
        base = os.path.basename(target_dylib)
        subprocess.run(["install_name_tool", "-change", original_path, f"@rpath/{base}", bundled_scrcpy], check=False)

    # Re-link dylibs to point to each other
    for dylib_name in os.listdir(FRAMEWORKS_DIR):
        dylib_path = os.path.join(FRAMEWORKS_DIR, dylib_name)
        if not os.path.isfile(dylib_path):
            continue

        subprocess.run(["install_name_tool", "-id", f"@rpath/{dylib_name}", dylib_path], check=False)
        subprocess.run(["install_name_tool", "-add_rpath", "@loader_path", dylib_path], check=False)

        deps = get_dependencies(dylib_path)
        for dep in deps:
            base = os.path.basename(os.path.realpath(dep))
            subprocess.run(["install_name_tool", "-change", dep, f"@rpath/{base}", dylib_path], check=False)

    print("--- 7. Ad-hoc Codesigning bundle ---")
    # Sign all dylibs
    for dylib_name in os.listdir(FRAMEWORKS_DIR):
        dylib_path = os.path.join(FRAMEWORKS_DIR, dylib_name)
        subprocess.run(["codesign", "--force", "--sign", "-", dylib_path], check=False)

    # Sign binaries
    subprocess.run(["codesign", "--force", "--sign", "-", bundled_adb], check=False)
    subprocess.run(["codesign", "--force", "--sign", "-", bundled_scrcpy], check=False)
    subprocess.run(["codesign", "--force", "--sign", "-", exec_path], check=False)

    # Sign whole app bundle
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", APP_BUNDLE], check=False)

    print("--- 8. Verifying bundled scrcpy ---")
    test_env = {
        "PATH": f"{BIN_DIR}:/usr/bin:/bin",
        "SCRCPY_SERVER_PATH": bundled_server,
        "DYLD_LIBRARY_PATH": FRAMEWORKS_DIR
    }
    ver_proc = subprocess.run([bundled_scrcpy, "--version"], env=test_env, capture_output=True, text=True)
    print("Bundled scrcpy test:")
    print(ver_proc.stdout)
    if ver_proc.returncode != 0:
        print("Scrcpy test error:", ver_proc.stderr)
        sys.exit(1)

    print(f"\n🎉 SUCCESS! Fully standalone app built at:\n{APP_BUNDLE}\n")

if __name__ == "__main__":
    main()
