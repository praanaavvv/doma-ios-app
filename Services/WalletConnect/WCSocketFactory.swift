import Foundation
import WalletConnectSign

class NativeWebSocket: NSObject, WebSocketConnecting, URLSessionWebSocketDelegate {
    var request: URLRequest
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?

    var isConnected: Bool = false {
        didSet {
            print("[NativeWebSocket] isConnected changed to: \(isConnected)")
        }
    }

    private var socket: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    init(request: URLRequest) {
        self.request = request
        super.init()
        let config = URLSessionConfiguration.default
        // WalletConnect relay requires a long-lived connection
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        print("[NativeWebSocket] Init with URL: \(request.url?.absoluteString ?? "nil")")
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    func connect() {
        print("[NativeWebSocket] Connecting to: \(request.url?.absoluteString ?? "unknown")")
        socket = urlSession.webSocketTask(with: request)
        socket?.resume()
        receiveMessage()
    }
    
    func disconnect() {
        print("[NativeWebSocket] Disconnecting")
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        isConnected = false
    }
    
    func write(string: String, completion: (() -> Void)?) {
        let message = URLSessionWebSocketTask.Message.string(string)
        socket?.send(message) { error in
            if let error = error {
                print("[NativeWebSocket] Send Error: \(error)")
            } else {
                completion?()
            }
        }
    }
    
    private func receiveMessage() {
        socket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.onText?(text)
                case .data(_):
                    // WalletConnect V2 uses text frames
                    break
                @unknown default:
                    break
                }
                self.receiveMessage() // Read next message
            case .failure(let error):
                print("[NativeWebSocket] Receive Error: \(error)")
                self.isConnected = false
                self.onDisconnect?(error)
            }
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol webSocketProtocol: String?) {
        print("[NativeWebSocket] Socket opened with protocol: \(webSocketProtocol ?? "none")")
        isConnected = true
        onConnect?()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[NativeWebSocket] Socket closed with code: \(closeCode.rawValue)")
        isConnected = false
        onDisconnect?(nil)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[NativeWebSocket] Task completed with error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("[NativeWebSocket] Error Code: \(nsError.code), Domain: \(nsError.domain)")
                if let response = (task.response as? HTTPURLResponse) {
                    print("[NativeWebSocket] HTTP Status Code: \(response.statusCode)")
                }
            }
            isConnected = false
            onDisconnect?(error)
        } else {
            print("[NativeWebSocket] Task completed successfully (no error)")
        }
    }
}

struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
        // --- 403 BYPASS WORKAROUND ---
        // Strip bundleId if present (sometimes causes 403 if relay verification is strict)
        var items = comps.queryItems ?? []
        items.removeAll { $0.name == "bundleId" }
        comps.queryItems = items
        
        // Ensure path is not empty
        if comps.path.isEmpty {
            comps.path = "/"
        }
        
        let finalURL = comps.url!
        var request = URLRequest(url: finalURL)
        request.timeoutInterval = 15
        
        // Essential headers for WalletConnect relay
        request.setValue("wc-2", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        
        // Add Origin header (some relays require this for 403 mitigation)
        request.setValue("https://com.d3globalinc.domasecureios", forHTTPHeaderField: "Origin")

        print("[WCSocketFactory] Creating Native Socket for: \(finalURL.absoluteString)")
        print("[WCSocketFactory] Setting Origin: https://com.d3globalinc.domasecureios")
        
        return NativeWebSocket(request: request)
    }
}
