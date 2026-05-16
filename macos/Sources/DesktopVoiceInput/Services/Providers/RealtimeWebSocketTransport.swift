import Foundation

enum RealtimeWebSocketIncomingMessage {
    case text(String)
    case data(Data)
}

final class RealtimeWebSocketTransport: @unchecked Sendable {
    private let session: URLSession
    private let task: URLSessionWebSocketTask
    private let sendLock = AsyncSendLock()
    private var receiveTask: Task<Void, Never>?
    private let onMessage: @Sendable (RealtimeWebSocketIncomingMessage) -> Void
    private let onDisconnected: @Sendable (Error?) -> Void

    init(
        request: URLRequest,
        onMessage: @escaping @Sendable (RealtimeWebSocketIncomingMessage) -> Void,
        onDisconnected: @escaping @Sendable (Error?) -> Void
    ) {
        self.session = URLSession(configuration: .default)
        self.task = session.webSocketTask(with: request)
        self.onMessage = onMessage
        self.onDisconnected = onDisconnected
    }

    func connect() {
        task.resume()
        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        onMessage(.text(text))
                    case .data(let data):
                        onMessage(.data(data))
                    @unknown default:
                        continue
                    }
                } catch {
                    if Task.isCancelled {
                        return
                    }

                    onDisconnected(error)
                    return
                }
            }
        }
    }

    func send(text: String) async throws {
        try await send(.string(text))
    }

    func send(data: Data) async throws {
        try await send(.data(data))
    }

    private func send(_ message: URLSessionWebSocketTask.Message) async throws {
        await sendLock.lock()
        do {
            try await task.send(message)
            await sendLock.unlock()
        } catch {
            await sendLock.unlock()
            throw error
        }
    }

    func close() {
        receiveTask?.cancel()
        task.cancel(with: .normalClosure, reason: nil)
        session.invalidateAndCancel()
        onDisconnected(nil)
    }
}

private actor AsyncSendLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func lock() async {
        if !isLocked {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func unlock() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }

        let next = waiters.removeFirst()
        next.resume()
    }
}
