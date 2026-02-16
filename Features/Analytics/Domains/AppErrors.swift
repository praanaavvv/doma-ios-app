import Foundation

/// Lightweight error wrapper for presenting friendly messages
struct SimpleError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
