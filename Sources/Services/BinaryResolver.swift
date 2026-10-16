import Foundation

public final class BinaryResolver {
    public static let shared = BinaryResolver()

    private let fileManager = FileManager.default

    public struct ResolvedPaths {
        public let adbPath: String
        public let scrcpyPath: String
        public let scrcpyServerPath: String
        public let isBundled: Bool
        public let frameworksPath: String?
    }

    private var cachedResolvedPaths: ResolvedPaths?

    private init() {}

    public func resolve() -> ResolvedPaths? {
        if let cached = cachedResolvedPaths {
            return cached
        }

        let bundleResourceURL = Bundle.main.resourceURL

        // 1. Check inside App Bundle (Contents/Resources/bin and Contents/Frameworks)
        var bundledAdb: String?
        var bundledScrcpy: String?
        var bundledServer: String?
        var bundledFrameworks: String?

        if let resURL = bundleResourceURL {
            let adbCandidate = resURL.appendingPathComponent("bin/adb").path
            let scrcpyCandidate = resURL.appendingPathComponent("bin/scrcpy").path
            let serverCandidate = resURL.appendingPathComponent("bin/scrcpy-server").path
            let frameworksCandidate = resURL.deletingLastPathComponent().appendingPathComponent("Frameworks").path

            if fileManager.isExecutableFile(atPath: adbCandidate) {
                bundledAdb = adbCandidate
            }
            if fileManager.isExecutableFile(atPath: scrcpyCandidate) {
                bundledScrcpy = scrcpyCandidate
            }
            if fileManager.fileExists(atPath: serverCandidate) {
                bundledServer = serverCandidate
            }
            if fileManager.fileExists(atPath: frameworksCandidate) {
                bundledFrameworks = frameworksCandidate
            }
        }

        if let bAdb = bundledAdb, let bScrcpy = bundledScrcpy, let bServer = bundledServer {
            let paths = ResolvedPaths(
                adbPath: bAdb,
                scrcpyPath: bScrcpy,
                scrcpyServerPath: bServer,
                isBundled: true,
                frameworksPath: bundledFrameworks
            )
            cachedResolvedPaths = paths
            return paths
        }

        // 2. Check Fallback system paths (Homebrew, Android SDK, /usr/local/bin)
        let homeDir = NSHomeDirectory()
        let adbCandidates = [
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
            "\(homeDir)/Library/Android/sdk/platform-tools/adb",
            "/usr/bin/adb"
        ]

        let scrcpyCandidates = [
            "/opt/homebrew/bin/scrcpy",
            "/usr/local/bin/scrcpy",
            "/usr/bin/scrcpy"
        ]

        let serverCandidates = [
            "/opt/homebrew/share/scrcpy/scrcpy-server",
            "/usr/local/share/scrcpy/scrcpy-server",
            "/opt/homebrew/Cellar/scrcpy/4.1_1/share/scrcpy/scrcpy-server"
        ]

        let adb = adbCandidates.first { fileManager.isExecutableFile(atPath: $0) }
        let scrcpy = scrcpyCandidates.first { fileManager.isExecutableFile(atPath: $0) }
        
        var server = serverCandidates.first { fileManager.fileExists(atPath: $0) }
        if server == nil {
            // Try wildcard lookup in Cellar
            let cellar = "/opt/homebrew/Cellar/scrcpy"
            if let versions = try? fileManager.contentsOfDirectory(atPath: cellar) {
                for v in versions {
                    let cand = "\(cellar)/\(v)/share/scrcpy/scrcpy-server"
                    if fileManager.fileExists(atPath: cand) {
                        server = cand
                        break
                    }
                }
            }
        }

        if let foundAdb = adb, let foundScrcpy = scrcpy, let foundServer = server {
            let paths = ResolvedPaths(
                adbPath: foundAdb,
                scrcpyPath: foundScrcpy,
                scrcpyServerPath: foundServer,
                isBundled: false,
                frameworksPath: nil
            )
            cachedResolvedPaths = paths
            return paths
        }

        return nil
    }

    public func buildEnvironment(paths: ResolvedPaths) -> [String: String] {
        var env = ProcessInfo.processInfo.environment

        let adbDir = (paths.adbPath as NSString).deletingLastPathComponent
        let scrcpyDir = (paths.scrcpyPath as NSString).deletingLastPathComponent
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "\(adbDir):\(scrcpyDir):\(currentPath)"
        env["SCRCPY_SERVER_PATH"] = paths.scrcpyServerPath

        if let fw = paths.frameworksPath {
            let currentDyld = env["DYLD_LIBRARY_PATH"] ?? ""
            env["DYLD_LIBRARY_PATH"] = currentDyld.isEmpty ? fw : "\(fw):\(currentDyld)"
        }

        return env
    }
}
