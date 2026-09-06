import Foundation

final class CommandCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var timedOut = false

    func start(_ process: Process) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { throw CancellationError() }
        try process.run()
        self.process = process
    }

    func cancel(timedOut: Bool = false) {
        lock.lock()
        cancelled = true
        self.timedOut = self.timedOut || timedOut
        let running = process
        lock.unlock()
        if let running, running.isRunning {
            running.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if running.isRunning { kill(running.processIdentifier, SIGKILL) }
            }
        }
    }

    func check() throws {
        lock.lock()
        defer { lock.unlock() }
        if timedOut { throw PluginValidationError(messages: [String(localized: "The command timed out after 60 seconds.")]) }
        if cancelled { throw CancellationError() }
    }
}
