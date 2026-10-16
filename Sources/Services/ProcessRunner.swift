import Foundation

public struct ProcessResult {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var isSuccess: Bool {
        return exitCode == 0
    }
}

public final class ProcessRunner {
    public static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 15.0
    ) async -> ProcessResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                if let env = environment {
                    process.environment = env
                }

                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ProcessResult(
                        exitCode: -1,
                        stdout: "",
                        stderr: "Failed to launch process: \(error.localizedDescription)"
                    ))
                    return
                }

                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + timeout)
                timer.setEventHandler {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                timer.resume()

                process.waitUntilExit()
                timer.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let outStr = String(data: outputData, encoding: .utf8) ?? ""
                let errStr = String(data: errorData, encoding: .utf8) ?? ""

                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: outStr,
                    stderr: errStr
                ))
            }
        }
    }
}
