import Foundation

enum RealtimeWebSocketIncomingMessage {
    case text(String)
    case data(Data)
}

final class RealtimeWebSocketTransport: @unchecked Sendable {
    private let session: URLSession
    private let task: URLSessionWebSocketTask
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
        try await task.send(.string(text))
    }

    func send(data: Data) async throws {
        try await task.send(.data(data))
    }

    func close() {
        receiveTask?.cancel()
        task.cancel(with: .normalClosure, reason: nil)
        session.invalidateAndCancel()
        onDisconnected(nil)
    }
}
