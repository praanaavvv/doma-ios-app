import Foundation
import WalletConnectSign

class NativeWebSocket: NSObject, WebSocketConnecting, URLSessionWebSocketDelegate {
    var request: URLRequest
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?

    var isConnected: Bool = false

    private var socket: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    init(request: URLRequest) {
        self.request = request
        super.init()
        let config = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }
    
    func connect() {
        socket = urlSession.webSocketTask(with: request)
        socket?.resume()
        receiveMessage()
    }
    
    func disconnect() {
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
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[NativeWebSocket] Connected")
        isConnected = true
        onConnect?()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[NativeWebSocket] Disconnected code: \(closeCode)")
        isConnected = false
        onDisconnect?(nil)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[NativeWebSocket] Session Completed with Error: \(error)")
            isConnected = false
            onDisconnect?(error)
        }
    }
}

struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        // Force trailing slash as required by relay
        if comps.path.isEmpty {
            comps.path = "/"
        }
        
        let finalURL = comps.url!
        var request = URLRequest(url: finalURL)
        request.timeoutInterval = 15
        request.setValue("wc-2", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        print("[WCSocketFactory] Connecting to (Native):", finalURL.absoluteString)
        return NativeWebSocket(request: request)
    }
}
