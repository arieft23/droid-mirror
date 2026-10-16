import Foundation
import Combine

@MainActor
public final class ScrcpyService: ObservableObject {
    public static let shared = ScrcpyService()

    @Published public var isMirroring: Bool = false
    @Published public var activeDeviceId: String?
    @Published public var logLines: [String] = []
    @Published public var errorMessage: String?

    private var currentProcess: Process?
    private let resolver = BinaryResolver.shared

    private init() {}

    public func startMirroring(device: Device, config: ScrcpyConfig) {
        guard !isMirroring else {
            errorMessage = "Mirroring sedang berjalan."
            return
        }

        guard let paths = resolver.resolve() else {
            errorMessage = "Binary scrcpy / adb tidak ditemukan."
            return
        }

        let env = resolver.buildEnvironment(paths: paths)
        var args: [String] = ["-s", device.id]

        // Quality & Display options
        if config.maxSize > 0 {
            args.append(contentsOf: ["--max-size", "\(config.maxSize)"])
        }
        if config.bitRateMbps > 0 {
            args.append(contentsOf: ["--video-bit-rate", "\(config.bitRateMbps)M"])
        }
        if config.maxFps > 0 {
            args.append(contentsOf: ["--max-fps", "\(config.maxFps)"])
        }

        if config.turnScreenOff {
            args.append("--turn-screen-off")
        }
        if config.stayAwake {
            args.append("--stay-awake")
        }
        if !config.audioEnabled {
            args.append("--no-audio")
        }
        if config.alwaysOnTop {
            args.append("--always-on-top")
        }
        if config.fullscreen {
            args.append("--fullscreen")
        }
        if config.showTouches {
            args.append("--show-touches")
        }

        let windowTitle = "DroidMirror - \(device.displayName)"
        args.append(contentsOf: ["--window-title", windowTitle])

        appendLog("Menjalankan: \(paths.scrcpyPath) \(args.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: paths.scrcpyPath)
        process.arguments = args
        process.environment = env

        let errPipe = Pipe()
        let outPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = outPipe

        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading

        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                Task { @MainActor [weak self] in
                    self?.appendLog("[scrcpy] \(str.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }

        errHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                Task { @MainActor [weak self] in
                    self?.appendLog("[error] \(str.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                self?.isMirroring = false
                self?.activeDeviceId = nil
                self?.currentProcess = nil
                self?.appendLog("Sesi mirror selesai (exit code: \(proc.terminationStatus)).")
            }
        }

        do {
            try process.run()
            self.currentProcess = process
            self.isMirroring = true
            self.activeDeviceId = device.id
            self.errorMessage = nil
        } catch {
            self.isMirroring = false
            self.activeDeviceId = nil
            self.errorMessage = "Gagal memulai scrcpy: \(error.localizedDescription)"
            appendLog("Error: \(error.localizedDescription)")
        }
    }

    public func stopMirroring() {
        guard let proc = currentProcess, proc.isRunning else { return }
        appendLog("Menghentikan mirroring...")
        proc.terminate()
        currentProcess = nil
        isMirroring = false
        activeDeviceId = nil
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        logLines.append(line)
        if logLines.count > 200 {
            logLines.removeFirst(50)
        }
    }
}
