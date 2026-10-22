import CryptoKit
import Foundation
import OSLog
import Security

/// Encrypts everything OptPaste writes to disk with AES-256-GCM.
///
/// The key is random, created once, and kept in the user's Keychain, which only hands it
/// to this app (identified by its code signature). Copying the files elsewhere is useless
/// without it.
final class Vault {
    enum VaultError: Error {
        case notEncrypted
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OptPaste", category: "vault")
    /// Marks encrypted files, so older plaintext files can be told apart and migrated.
    private static let magic = Data("OPV1".utf8)

    private let key: SymmetricKey

    /// Nil when the Keychain can't provide a key; the history then stays in memory only.
    init?() {
        guard let key = Self.loadOrCreateKey() else { return nil }
        self.key = key
    }

    func seal(_ data: Data) throws -> Data {
        // `combined` is only nil for custom nonce sizes; the default nonce always has it.
        Self.magic + (try AES.GCM.seal(data, using: key).combined ?? Data())
    }

    func open(_ data: Data) throws -> Data {
        guard data.starts(with: Self.magic) else { throw VaultError.notEncrypted }
        let box = try AES.GCM.SealedBox(combined: data.dropFirst(Self.magic.count))
        return try AES.GCM.open(box, using: key)
    }

    static func isEncrypted(_ data: Data) -> Bool {
        data.starts(with: magic)
    }

    // MARK: - Keychain

    private static let service = (Bundle.main.bundleIdentifier ?? "OptPaste") + ".history"
    private static let account = "encryption-key"

    private static func loadOrCreateKey() -> SymmetricKey? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else {
            // Never replace a key that exists but couldn't be read: that would orphan the history.
            log.error("Keychain indisponível (\(status, privacy: .public)); histórico só em memória")
            return nil
        }

        let key = SymmetricKey(size: .bits256)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrLabel: "OptPaste – chave do histórico",
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: key.withUnsafeBytes { Data($0) },
        ]
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            log.error("Não foi possível salvar a chave (\(addStatus, privacy: .public)); histórico só em memória")
            return nil
        }
        return key
    }
}
