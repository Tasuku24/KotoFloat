import Foundation
import Observation

enum TranslationFailure: String, Error, Equatable {
    case invalidEndpoint, insecureConnection, credentialsUnavailable, invalidToken, modelRequired
    case authentication, modelUnavailable, rateLimited, serverUnavailable, requestRejected
    case malformedResponse, interrupted, timedOut, network, outputTooLarge, emptyResponse, truncated
}

struct ServerConfiguration: Equatable, Sendable {
    let baseURL: URL
    let model: String
    let allowHTTP: Bool
    init(endpoint: String, model: String, allowHTTP: Bool = false) throws {
        let input = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.count <= 2_048, var parts = URLComponents(string: input),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parts.host?.lowercased(), !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.port == nil || (1...65_535).contains(parts.port!), model.count <= 512 else {
            throw TranslationFailure.invalidEndpoint
        }
        guard scheme == "https" || allowHTTP || ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host) else {
            throw TranslationFailure.insecureConnection
        }
        parts.scheme = scheme
        parts.host = host
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        if !parts.path.hasSuffix("/v1") { parts.path += "/v1" }
        guard let url = parts.url else { throw TranslationFailure.invalidEndpoint }
        baseURL = url
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.allowHTTP = allowHTTP
    }
    var modelsURL: URL { baseURL.appendingPathComponent("models") }
    var chatURL: URL { baseURL.appendingPathComponent("chat/completions") }
}

enum TranslationLanguage: String, CaseIterable, Sendable { case automatic, english = "en", japanese = "ja" }
enum TokenUpdate { case keep, replace(String), remove }

@MainActor @Observable final class TranslationPreferences {
    @ObservationIgnored private let defaults: UserDefaults
    private(set) var server: ServerConfiguration?
    private(set) var revision = 0
    var sourceLanguage: TranslationLanguage {
        didSet { defaults.set(sourceLanguage.rawValue, forKey: "translation.sourceLanguage") }
    }
    var targetLanguage: TranslationLanguage {
        didSet { defaults.set(targetLanguage.rawValue, forKey: "translation.targetLanguage") }
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sourceLanguage = defaults.string(forKey: "translation.sourceLanguage").flatMap(TranslationLanguage.init(rawValue:)) ?? .automatic
        let target = defaults.string(forKey: "translation.targetLanguage").flatMap(TranslationLanguage.init(rawValue:))
        targetLanguage = target == .english ? .english : .japanese
        if let endpoint = defaults.string(forKey: "translation.endpoint") {
            server = try? ServerConfiguration(endpoint: endpoint, model: defaults.string(forKey: "translation.model") ?? "",
                allowHTTP: defaults.bool(forKey: "translation.allowHTTP"))
        }
    }
    func save(_ server: ServerConfiguration, tokenUpdate: TokenUpdate, credentials: any CredentialStore) throws {
        switch tokenUpdate {
        case .keep: break
        case .replace(let token):
            guard !token.contains(where: \.isNewline) else { throw TranslationFailure.invalidToken }
            try credentials.setToken(token, for: server.baseURL.absoluteString)
        case .remove: try credentials.setToken(nil, for: server.baseURL.absoluteString)
        }
        defaults.set(server.baseURL.absoluteString, forKey: "translation.endpoint")
        defaults.set(server.model, forKey: "translation.model")
        defaults.set(server.allowHTTP, forKey: "translation.allowHTTP")
        self.server = server
        revision += 1
    }
}
