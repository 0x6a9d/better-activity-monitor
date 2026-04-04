import Foundation
import OSLog

actor CommandRunner {
    private let logger = Logger(subsystem: "ActivityMonitorDashboard", category: "CommandRunner")

    func run(executable: String, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                let combinedOutput = Pipe()
                process.standardOutput = combinedOutput
                process.standardError = combinedOutput

                let commandDescription = ([executable] + arguments).joined(separator: " ")

                do {
                    try process.run()
                } catch {
                    self.logger.error("Failed to run command: \(commandDescription, privacy: .public). Error: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: nil)
                    return
                }

                let outputData = combinedOutput.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let output = String(decoding: outputData, as: UTF8.self)

                guard process.terminationStatus == 0 else {
                    if output.isEmpty {
                        self.logger.error("Command exited with status \(process.terminationStatus): \(commandDescription, privacy: .public)")
                    } else {
                        self.logger.error("Command exited with status \(process.terminationStatus): \(commandDescription, privacy: .public). Output: \(output, privacy: .public)")
                    }
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: output)
            }
        }
    }
}
