import Foundation

/// Runs a command-line tool (afconvert, textutil, soffice, osascript…) without a shell,
/// so file names are passed as plain arguments and can never be interpreted as commands.
enum Shell {
    /// - Parameter timeout: the tool is stopped if it runs longer (a hung LibreOffice must not
    ///   leave "Procesando…" in the menu forever).
    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String],
        currentDirectory: URL? = nil,
        timeout: Duration = .seconds(300)
    ) async throws -> String {
        // Output goes to a temp file instead of a pipe: a full pipe buffer could block the tool forever.
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("gota-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: log)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = handle
        process.standardError = handle
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        let watchdog = Task {
            try await Task.sleep(for: timeout)
            if process.isRunning { process.terminate() }
        }
        defer { watchdog.cancel() }

        let status: Int32 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { finished in
                    continuation.resume(returning: finished.terminationStatus)
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() } // terminate() on a process that never started would crash
        }

        let name = URL(fileURLWithPath: executable).lastPathComponent
        if process.terminationReason == .uncaughtSignal {
            throw ConversionError.toolFailed(tool: name, output: "se detuvo (tardó demasiado o fue cancelado).")
        }
        let output = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        guard status == 0 else {
            throw ConversionError.toolFailed(tool: name, output: output)
        }
        return output
    }
}
