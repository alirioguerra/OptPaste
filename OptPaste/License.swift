import Foundation
import OSLog
import Security

/// Free trial followed by a license key bought through Paddle.
///
/// Keys are issued and activated by the site's license API (`optpaste-site/api`). Trial start and
/// the activated key live in the Keychain, which outlives reinstalls. Once activated, the app only
/// drops the license when the API says it is no longer valid (e.g. refunded); being offline never
/// locks anyone out.
@Observable
final class License {
    enum Status: Equatable {
        case trial(daysLeft: Int)
        case expired
        case licensed(email: String?)
    }

    enum ActivationError: LocalizedError {
        case rejected(String?)
        case unreachable

        var errorDescription: String? {
            switch self {
            case .rejected(let message?) where message.contains("not found"):
                "Chave não encontrada. Confira se copiou a chave inteira."
            case .rejected(let message?) where message.contains("activation limit"):
                "Esta chave já está ativa no número máximo de Macs. Desative-a em outro Mac."
            case .rejected(let message?) where message.contains("expired") || message.contains("disabled"):
                "Esta chave expirou ou foi desativada."
            case .rejected(let message): message ?? "Chave inválida."
            case .unreachable: "Não foi possível falar com o servidor de licenças. Verifique sua conexão."
            }
        }
    }

    static let trialDays = 14
    static let checkoutURL = URL(string: "https://optpaste-site.vercel.app/#comprar")!

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OptPaste", category: "license")
    private static let api = URL(string: "https://optpaste-site.vercel.app/api/license/")!

    private var activation: Activation?
    private let trialStart: Date

    var status: Status {
        if let activation { return .licensed(email: activation.email) }
        let elapsed = Calendar.current.dateComponents([.day], from: trialStart, to: .now).day ?? 0
        let daysLeft = Self.trialDays - max(elapsed, 0)
        return daysLeft > 0 ? .trial(daysLeft: daysLeft) : .expired
    }

    var isUsable: Bool { status != .expired }

    init() {
        activation = Keychain.read(Activation.self, account: Keychain.activationAccount)
        if let start = Keychain.read(Date.self, account: Keychain.trialAccount) {
            trialStart = start
        } else {
            trialStart = .now
            Keychain.write(trialStart, account: Keychain.trialAccount)
        }
    }

    /// Confirms a stored key is still valid (not refunded or disabled). Call on launch.
    func revalidate() async {
        guard let activation else { return }
        do {
            let response = try await call("validate", ["license_key": activation.key, "instance_id": activation.instanceID])
            if response.valid == false {
                Self.log.notice("Licença não é mais válida: \(response.error ?? "-", privacy: .public)")
                forget()
            }
        } catch {
            Self.log.error("Não foi possível validar a licença: \(error.localizedDescription, privacy: .public)")
        }
    }

    func activate(key: String) async throws {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = Host.current().localizedName ?? "Mac"
        let response: Response
        do {
            response = try await call("activate", ["license_key": key, "instance_name": name])
        } catch {
            Self.log.error("Falha ao ativar a licença: \(error.localizedDescription, privacy: .public)")
            throw ActivationError.unreachable
        }
        guard response.activated == true, let instanceID = response.instance?.id else {
            throw ActivationError.rejected(response.error)
        }
        let activation = Activation(key: key, instanceID: instanceID, email: response.meta?.customerEmail)
        Keychain.write(activation, account: Keychain.activationAccount)
        self.activation = activation
    }

    /// Frees this Mac's activation so the key can be used on another one.
    func deactivate() async {
        guard let activation else { return }
        _ = try? await call("deactivate", ["license_key": activation.key, "instance_id": activation.instanceID])
        forget()
    }

    private func forget() {
        Keychain.delete(account: Keychain.activationAccount)
        activation = nil
    }

    // MARK: - License API

    private func call(_ endpoint: String, _ fields: [String: String]) async throws -> Response {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: Self.api.appending(path: endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // `+` is legal in a query but means a space in a form body.
        request.httpBody = Data((components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
        // Refused keys come back as 4xx with the same JSON shape, so the status code isn't checked.
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private struct Response: Decodable {
        struct Instance: Decodable {
            let id: String
        }

        struct Meta: Decodable {
            let customerEmail: String?

            enum CodingKeys: String, CodingKey {
                case customerEmail = "customer_email"
            }
        }

        let activated: Bool?
        let valid: Bool?
        let error: String?
        let instance: Instance?
        let meta: Meta?
    }

    private struct Activation: Codable {
        let key: String
        let instanceID: String
        let email: String?
    }
}

/// JSON values in the app's Keychain items.
private enum Keychain {
    static let service = (Bundle.main.bundleIdentifier ?? "OptPaste") + ".license"
    static let trialAccount = "trial-start"
    static let activationAccount = "activation"

    static func read<T: Decodable>(_ type: T.Type, account: String) -> T? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func write(_ value: some Encodable, account: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        delete(account: account)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrLabel: "OptPaste – licença",
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData: data,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
