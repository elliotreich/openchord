import Foundation

enum AppError: Error, Codable, Equatable, LocalizedError, Sendable {
    case authorizationRequired
    case subscriptionRequired
    case cloudLibraryUnavailable
    case networkUnavailable
    case musicKitSetupRequired
    case musicKit(message: String)
    case unsupportedAction(action: String)
    case invalidInput(message: String)
    case unknown(message: String)

    static func from(_ error: Error) -> AppError {
        if let error = error as? AppError {
            return error
        }
        let description = error.localizedDescription
        let diagnostic = String(describing: error)
        if description.localizedCaseInsensitiveContains("developer token") || diagnostic.contains("developerTokenRequestFailed") {
            return .musicKitSetupRequired
        }
        return .musicKit(message: error.localizedDescription)
    }

    var userFacingMessage: String {
        [errorDescription, recoverySuggestion]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var errorDescription: String? {
        switch self {
        case .authorizationRequired:
            return "Apple Music authorization is required."
        case .subscriptionRequired:
            return "An active Apple Music subscription is required."
        case .cloudLibraryUnavailable:
            return "Apple Music Cloud Library is unavailable."
        case .networkUnavailable:
            return "Apple Music could not be reached."
        case .musicKitSetupRequired:
            return "This build is not registered for MusicKit developer-token access."
        case .musicKit(let message), .invalidInput(let message), .unknown(let message):
            return message
        case .unsupportedAction(let action):
            return "Apple Music does not support \(action) from this app."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authorizationRequired:
            return "Open Settings and allow OpenChord to access Apple Music, then try again."
        case .subscriptionRequired:
            return "Sign in to an active Apple Music subscription and retry."
        case .cloudLibraryUnavailable:
            return "Enable Sync Library in the Music app, then retry."
        case .networkUnavailable:
            return "Check the network connection and retry."
        case .musicKitSetupRequired:
            return "Register this bundle identifier with your Apple Developer team, enable MusicKit App Service, sign the app with that team, and retry. Each user still authorizes their own Apple Music account."
        case .unsupportedAction:
            return "Open the item in the Music app to perform this action."
        case .musicKit, .invalidInput, .unknown:
            return "Retry the operation. If it continues, copy diagnostics from Settings."
        }
    }
}
