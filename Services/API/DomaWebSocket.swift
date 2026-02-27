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

    private var pingTimer: Timer?
    private var isConnected = false

    func connect(domain: String) {
        if let current = self.domain, current != domain {
            disconnect()
        }
        
        self.domain = domain
        guard let url = URL(string: "\(serverURL)/?domain=\(domain)") else { return }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10 // fail fast if server is unreachable
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()
        listen()
        startPing()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        isConnected = false
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
                print("[WS] receive error: \(error.localizedDescription)")
                self?.isConnected = false
                self?.reconnect()
            }
        }
    }

    private func reconnect() {
        guard !isConnected else { return }
        print("[WS] Attempting to reconnect in 2 seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if let domain = self?.domain {
                self?.connect(domain: domain)
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
            print("[WS] Received reload_groups for conversation: \(convId)")
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
        pingTimer?.invalidate()
        // Fire every 15s to keep Render instances alive
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let ws = self?.webSocket, self?.isConnected == true else { return }
            let ping = #"{"type":"ping"}"#
            ws.send(.string(ping)) { error in
                if let error = error {
                    print("[WS] Ping failed: \(error.localizedDescription)")
                    self?.isConnected = false
                    self?.reconnect()
                }
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        print("[WS] Connection opened")
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[WS] Connection closed with code: \(closeCode)")
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.reconnect()
        }
    }
}
// MARK: - Notification Names

public extension Notification.Name {
    static let domaReloadConversations = Notification.Name("domaReloadConversations")
    static let domaReloadGroups = Notification.Name("domaReloadGroups")
    static let domaNewMessage = Notification.Name("domaNewMessage")
}
