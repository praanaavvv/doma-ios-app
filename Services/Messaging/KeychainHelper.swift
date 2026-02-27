import Foundation
import Security

/// A simple utility to securely store and retrieve Data in the iOS Keychain.
final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    /// Saves data to the Keychain for a specific key.
    func save(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item with the same key before saving
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("KeychainHelper: ❌ Failed to save data for key \(key). Status: \(status)")
        } else {
            print("KeychainHelper: ✅ Successfully saved data for key \(key).")
        }
    }
    
    /// Retrieves data from the Keychain for a specific key.
    func read(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne as String
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        } else {
            print("KeychainHelper: ⚠️ No data found for key \(key). Status: \(status)")
            return nil
        }
    }
    
    /// Deletes the data associated with a specific key from the Keychain.
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("KeychainHelper: ✅ Deleted data for key \(key).")
        } else if status != errSecItemNotFound {
            print("KeychainHelper: ❌ Failed to delete data for key \(key). Status: \(status)")
        }
    }
}
