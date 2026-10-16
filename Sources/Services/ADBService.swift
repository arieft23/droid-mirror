import Foundation
import Combine
import AppKit

@MainActor
public final class ADBService: ObservableObject {
    public static let shared = ADBService()

    @Published public var devices: [Device] = []
    @Published public var selectedDeviceId: String?
    @Published public var isScanning: Bool = false
    @Published public var statusMessage: String = ""
    @Published public var lastError: String?

    private var pollTimer: Timer?
    private let resolver = BinaryResolver.shared

    private init() {
        startAutoRefresh()
    }

    public var selectedDevice: Device? {
        guard let id = selectedDeviceId else {
            return devices.first
        }
        return devices.first { $0.id == id } ?? devices.first
    }

    public func startAutoRefresh() {
        refreshDevices()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDevices(silent: true)
            }
        }
    }

    public func stopAutoRefresh() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    public func refreshDevices(silent: Bool = false) {
        guard let paths = resolver.resolve() else {
            if !silent {
                lastError = "Binary adb/scrcpy tidak ditemukan di bundle aplikasi maupun di sistem!"
            }
            return
        }

        if !silent {
            isScanning = true
        }

        Task {
            let env = resolver.buildEnvironment(paths: paths)
            let result = await ProcessRunner.run(
                executable: paths.adbPath,
                arguments: ["devices", "-l"],
                environment: env,
                timeout: 5.0
            )

            let parsed = parseDevicesOutput(result.stdout)

            // Update battery for ready devices in parallel
            var updatedDevices: [Device] = []
            for var dev in parsed {
                if dev.state == .ready {
                    let battery = await fetchBatteryLevel(device: dev, adbPath: paths.adbPath, env: env)
                    dev.batteryLevel = battery
                }
                updatedDevices.append(dev)
            }

            self.devices = updatedDevices

            if self.selectedDeviceId == nil || !self.devices.contains(where: { $0.id == self.selectedDeviceId }) {
                self.selectedDeviceId = self.devices.first?.id
            }

            self.isScanning = false
        }
    }

    private func parseDevicesOutput(_ output: String) -> [Device] {
        var result: [Device] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("List of devices attached") || trimmed.hasPrefix("*") {
                continue
            }

            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }

            let serial = parts[0]
            let rawState = parts[1]
            let state: DeviceState
            switch rawState {
            case "device": state = .ready
            case "unauthorized": state = .unauthorized
            case "offline": state = .offline
            default: state = .unknown
            }

            var model = ""
            var product = ""
            var deviceName = ""
            var transportId = ""

            for part in parts.dropFirst(2) {
                if part.hasPrefix("model:") {
                    model = String(part.dropFirst("model:".count))
                } else if part.hasPrefix("product:") {
                    product = String(part.dropFirst("product:".count))
                } else if part.hasPrefix("device:") {
                    deviceName = String(part.dropFirst("device:".count))
                } else if part.hasPrefix("transport_id:") {
                    transportId = String(part.dropFirst("transport_id:".count))
                }
            }

            let isWifi = serial.contains(":") && (serial.split(separator: ".").count == 4 || serial.contains("192.168.") || serial.contains("10."))
            let connType: ConnectionType = isWifi ? .wifi : .usb

            result.append(Device(
                id: serial,
                model: model,
                product: product,
                deviceName: deviceName,
                transportId: transportId,
                state: state,
                connectionType: connType
            ))
        }

        return result
    }

    private func fetchBatteryLevel(device: Device, adbPath: String, env: [String: String]) async -> Int? {
        let res = await ProcessRunner.run(
            executable: adbPath,
            arguments: ["-s", device.id, "shell", "dumpsys", "battery"],
            environment: env,
            timeout: 3.0
        )
        for line in res.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("level:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count == 2, let level = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    return level
                }
            }
        }
        return nil
    }

    public func getDeviceIP(device: Device) async -> String? {
        guard let paths = resolver.resolve() else { return nil }
        let env = resolver.buildEnvironment(paths: paths)

        // Try 'ip -f inet addr show wlan0'
        let res = await ProcessRunner.run(
            executable: paths.adbPath,
            arguments: ["-s", device.id, "shell", "ip -f inet addr show wlan0"],
            environment: env,
            timeout: 3.0
        )

        // Parse inet 192.168.x.x/24
        for line in res.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("inet ") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let idx = parts.firstIndex(of: "inet"), idx + 1 < parts.count {
                    let cidr = parts[idx + 1]
                    let ip = cidr.components(separatedBy: "/")[0]
                    if !ip.isEmpty && ip != "127.0.0.1" {
                        return ip
                    }
                }
            }
        }

        // Fallback: ip route
        let resRoute = await ProcessRunner.run(
            executable: paths.adbPath,
            arguments: ["-s", device.id, "shell", "ip route"],
            environment: env,
            timeout: 3.0
        )
        for line in resRoute.stdout.components(separatedBy: .newlines) {
            if line.contains("wlan0") && line.contains("src ") {
                let parts = line.components(separatedBy: .whitespaces)
                if let idx = parts.firstIndex(of: "src"), idx + 1 < parts.count {
                    return parts[idx + 1]
                }
            }
        }

        return nil
    }

    public func enableWirelessMode(device: Device) async -> Result<String, Error> {
        guard let paths = resolver.resolve() else {
            return .failure(NSError(domain: "DroidMirror", code: 1, userInfo: [NSLocalizedDescriptionKey: "Binary adb tidak ditemukan."]))
        }
        let env = resolver.buildEnvironment(paths: paths)

        guard let ip = await getDeviceIP(device: device) else {
            return .failure(NSError(domain: "DroidMirror", code: 2, userInfo: [NSLocalizedDescriptionKey: "Tidak dapat mendeteksi IP Wi-Fi perangkat. Pastikan HP dan Mac terhubung ke Wi-Fi yang sama."]))
        }

        // Run tcpip 5555
        let tcpRes = await ProcessRunner.run(
            executable: paths.adbPath,
            arguments: ["-s", device.id, "tcpip", "5555"],
            environment: env,
            timeout: 5.0
        )

        if !tcpRes.isSuccess {
            return .failure(NSError(domain: "DroidMirror", code: 3, userInfo: [NSLocalizedDescriptionKey: "Gagal mengaktifkan mode TCP/IP: \(tcpRes.stderr)"]))
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Connect to IP:5555
        let connRes = await ProcessRunner.run(
            executable: paths.adbPath,
            arguments: ["connect", "\(ip):5555"],
            environment: env,
            timeout: 8.0
        )

        if connRes.stdout.contains("connected") {
            refreshDevices()
            return .success(ip)
        } else {
            return .failure(NSError(domain: "DroidMirror", code: 4, userInfo: [NSLocalizedDescriptionKey: "Koneksi nirkabel gagal: \(connRes.stdout) \(connRes.stderr)"]))
        }
    }

    public func disconnectWireless(ip: String) async {
        guard let paths = resolver.resolve() else { return }
        let env = resolver.buildEnvironment(paths: paths)
        _ = await ProcessRunner.run(
            executable: paths.adbPath,
            arguments: ["disconnect", ip],
            environment: env,
            timeout: 4.0
        )
        refreshDevices()
    }

    public func takeScreenshot(device: Device) async -> URL? {
        guard let paths = resolver.resolve() else { return nil }
        let env = resolver.buildEnvironment(paths: paths)

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Screenshot_\(formatter.string(from: Date())).png"
        let destinationURL = downloadsURL.appendingPathComponent(filename)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: paths.adbPath)
        process.arguments = ["-s", device.id, "exec-out", "screencap", "-p"]
        process.environment = env

        let outPipe = Pipe()
        process.standardOutput = outPipe

        do {
            try process.run()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if process.terminationStatus == 0 && !data.isEmpty {
                try data.write(to: destinationURL)
                return destinationURL
            }
        } catch {
            print("Screenshot error: \(error)")
        }
        return nil
    }

    public func sendKeyEvent(device: Device, keyCode: Int) {
        guard let paths = resolver.resolve() else { return }
        let env = resolver.buildEnvironment(paths: paths)
        Task {
            _ = await ProcessRunner.run(
                executable: paths.adbPath,
                arguments: ["-s", device.id, "shell", "input", "keyevent", "\(keyCode)"],
                environment: env,
                timeout: 3.0
            )
        }
    }

    public func installAPK(device: Device, fileURL: URL) async -> Result<String, Error> {
        guard let paths = resolver.resolve() else {
            return .failure(NSError(domain: "DroidMirror", code: 1, userInfo: [NSLocalizedDescriptionKey: "adb binary tidak ditemukan."]))
        }
        let env = resolver.buildEnvironment(paths: paths)

        let res = await ProcessRunner.run(
            executable: paths.adbPath,
            arguments: ["-s", device.id, "install", "-r", fileURL.path],
            environment: env,
            timeout: 45.0
        )

        if res.stdout.contains("Success") {
            return .success("APK berhasil terpasang di HP!")
        } else {
            return .failure(NSError(domain: "DroidMirror", code: 5, userInfo: [NSLocalizedDescriptionKey: res.stderr.isEmpty ? res.stdout : res.stderr]))
        }
    }

    public func restartServer() async {
        guard let paths = resolver.resolve() else { return }
        let env = resolver.buildEnvironment(paths: paths)
        _ = await ProcessRunner.run(executable: paths.adbPath, arguments: ["kill-server"], environment: env)
        _ = await ProcessRunner.run(executable: paths.adbPath, arguments: ["start-server"], environment: env)
        refreshDevices()
    }
}
