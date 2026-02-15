import Foundation
import AuthenticationServices

@MainActor
final class DynamicAuthSession: NSObject {
    private var session: ASWebAuthenticationSession?

    func start(url: URL, callbackScheme: String, onResult: @escaping (Result<URL, Error>) -> Void) {
        // Cancel any previous attempt
        session?.cancel()

        let s = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
            if let callbackURL {
                onResult(.success(callbackURL))
            } else if let error {
                onResult(.failure(error))
            } else {
                onResult(.failure(NSError(domain: "DynamicAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown auth error"])))
            }
        }

        // Better UX
        s.presentationContextProvider = self
        s.prefersEphemeralWebBrowserSession = true

        self.session = s
        _ = s.start()
    }
}

extension DynamicAuthSession: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Uses the key window
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
