import Foundation
import Combine

class DomaWebSocket: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    @Published private(set) var domain: String?
    private let serverURL: String

    override init() {
        // Derive the WebSocket URL dynamically from APIClient.shared.baseURL
        let apiURL = APIClient.shared.baseURL
        let scheme = apiURL.scheme == "https" ? "wss" : "ws"
        let host = apiURL.host ?? "localhost"
        let portString = apiURL.port.map { ":\($0)" } ?? ""
        self.serverURL = "\(scheme)://\(host)\(portString)"
        super.init()
    }

    // MARK: - Connect / Disconnect

    func connect(domain: String) {
        // Disconnect existing if we are switching domains
        if let current = self.domain, current != domain {
            disconnect()
        }
        
        self.domain = domain
        // Add a trailing slash before the query parameter
        guard let url = URL(string: "\(serverURL)/?domain=\(domain)") else { return }
        
        // Disable cache on the request to be extra safe
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()
        listen()
        startPing()
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        domain = nil
    }

    // MARK: - Send message_sent event

    func sendMessageEvent(to recipientDomain: String, conversationId: String) {
        guard let domain = self.domain else { return }
        
        let payload: [String: String] = [
            "type": "message_sent",
            "from": domain,
            "to": recipientDomain,
            "conversationId": conversationId
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        
        webSocket?.send(.string(json)) { error in
            if let error { print("[WS] send error:", error) }
        }
    }

    // MARK: - Listen for server events

    private func listen() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                default: break
                }
                self?.listen() // keep listening
            case .failure(let error):
                print("[WS] receive error:", error)
                // Reconnect after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if let domain = self?.domain {
                        self?.connect(domain: domain)
                    }
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "connected":
            print("[WS] Connected as \(json["domain"] ?? "")")

        case "reload_conversations":
            let convId = json["conversationId"] as? String ?? ""
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .domaReloadConversations,
                    object: nil,
                    userInfo: ["conversationId": convId]
                )
            }

        case "reload_groups":
            let convId = json["conversationId"] as? String ?? ""
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .domaReloadGroups,
                    object: nil,
                    userInfo: ["conversationId": convId]
                )
            }

        case "new_message":
            let from = json["from"] as? String ?? ""
            let convId = json["conversationId"] as? String ?? ""
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .domaNewMessage,
                    object: nil,
                    userInfo: ["from": from, "conversationId": convId]
                )
            }

        case "pong":
            break // keepalive ack

        default:
            print("[WS] Unknown event:", type)
        }
    }

    // MARK: - Keepalive

    private func startPing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let ws = self?.webSocket else { return }
            let ping = #"{"type":"ping"}"#
            ws.send(.string(ping)) { _ in }
            self?.startPing()
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        print("[WS] Connection opened")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[WS] Connection closed")
        // Auto-reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if let domain = self?.domain {
                self?.connect(domain: domain)
            }
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let domaReloadConversations = Notification.Name("domaReloadConversations")
    static let domaReloadGroups = Notification.Name("domaReloadGroups")
    static let domaNewMessage = Notification.Name("domaNewMessage")
}
