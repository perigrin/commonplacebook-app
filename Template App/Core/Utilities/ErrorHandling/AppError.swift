//
//  AppError.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation

/// Application error types
enum AppError: Error, Identifiable, Equatable {
    /// Network errors
    case network(NetworkError)
    /// Repository errors
    case repository(RepositoryError)
    /// Authentication errors
    case authentication(AuthenticationError)
    /// Validation errors
    case validation(ValidationError)
    /// Generic errors
    case general(String)
    /// Unknown errors
    case unknown(Error)
    
    /// Unique identifier for the error
    var id: String {
        switch self {
        case .network(let error):
            return "network_\(error.localizedDescription.hashValue)"
        case .repository(let error):
            return "repository_\(error.localizedDescription.hashValue)"
        case .authentication(let error):
            return "authentication_\(error.localizedDescription.hashValue)"
        case .validation(let error):
            return "validation_\(error.localizedDescription.hashValue)"
        case .general(let message):
            return "general_\(message.hashValue)"
        case .unknown(let error):
            return "unknown_\(error.localizedDescription.hashValue)"
        }
    }
    
    /// User-friendly error message
    var localizedDescription: String {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .repository(let error):
            return error.localizedDescription
        case .authentication(let error):
            return error.localizedDescription
        case .validation(let error):
            return error.localizedDescription
        case .general(let message):
            return message
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    /// Suggestion for how to recover from the error
    var recoverySuggestion: String? {
        switch self {
        case .network(let error):
            // Direct cast since error should be NetworkError
            guard let networkError = error as? NetworkError else {
                return nil // Handle non-NetworkError gracefully
            }
            switch networkError {
            case .noInternetConnection:
                return "Please check your internet connection and try again."
            case .serverError(let statusCode, _):
                return statusCode >= 500 ? "Please try again later." : "Please check your input and try again."
            case .timeoutError:
                return "The server is taking too long to respond. Please try again later."
            default:
                return "Please try again later."
            }
        case .repository:
            return "Please try again. If the problem persists, restart the app."
        case .authentication:
            return "Please log in again."
        case .validation:
            return "Please check your input and try again."
        case .general, .unknown:
            return "Please try again later."
        }
    }
    
    /// Log level for the error
    var logLevel: Logger.Level {
        switch self {
        case .network(let error):
            if let networkError = error as? NetworkError {
                switch networkError {
                case .serverError(let statusCode, _):
                    return statusCode >= 500 ? .error : .warning
                case .noInternetConnection, .timeoutError:
                    return .warning
                default:
                    return .error
                }
            }
            return .error
        case .repository:
            return .error
        case .authentication:
            return .warning
        case .validation:
            return .warning
        case .general:
            return .warning
        case .unknown:
            return .error
        }
    }
    
    /// Indicates if the error is retryable
    var isRetryable: Bool {
        switch self {
        case .network(let error):
            if let networkError = error as? NetworkError {
                switch networkError {
                case .noInternetConnection, .timeoutError:
                    return true
                case .serverError(let statusCode, _):
                    return statusCode >= 500
                default:
                    return false
                }
            }
            return false
        case .repository:
            return true
        case .authentication, .validation:
            return false
        case .general, .unknown:
            return true
        }
    }
    
    /// Equal operator for comparing errors
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Creates an AppError from any error
    /// - Parameter error: The error to convert
    /// - Returns: An AppError
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        } else if let networkError = error as? NetworkError {
            return .network(networkError)
        } else if let repositoryError = error as? RepositoryError {
            return .repository(repositoryError)
        } else if let authenticationError = error as? AuthenticationError {
            return .authentication(authenticationError)
        } else if let validationError = error as? ValidationError {
            return .validation(validationError)
        } else {
            return .unknown(error)
        }
    }
}

/// Authentication error types
enum AuthenticationError: Error, LocalizedError {
    /// Invalid credentials
    case invalidCredentials
    /// Session expired
    case sessionExpired
    /// Not authenticated
    case notAuthenticated
    /// Permission denied
    case permissionDenied
    /// Biometric authentication failed
    case biometricAuthenticationFailed
    /// Account locked
    case accountLocked
    /// Token expired
    case tokenExpired
    /// Token invalid
    case tokenInvalid
    
    /// User-friendly error message
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        case .notAuthenticated:
            return "You need to be logged in to perform this action."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed."
        case .accountLocked:
            return "Your account has been locked. Please contact support."
        case .tokenExpired:
            return "Your authentication token has expired. Please log in again."
        case .tokenInvalid:
            return "Your authentication token is invalid. Please log in again."
        }
    }
}

/// Validation error types
enum ValidationError: Error, LocalizedError {
    /// Required field missing
    case requiredFieldMissing(String)
    /// Invalid format
    case invalidFormat(String)
    /// Invalid length
    case invalidLength(String)
    /// Invalid value
    case invalidValue(String)
    /// Values don't match
    case valuesDontMatch(String)
    /// Maximum value exceeded
    case maxValueExceeded(String)
    /// Minimum value not met
    case minValueNotMet(String)
    
    /// User-friendly error message
    var errorDescription: String? {
        switch self {
        case .requiredFieldMissing(let field):
            return "\(field) is required."
        case .invalidFormat(let field):
            return "\(field) has an invalid format."
        case .invalidLength(let field):
            return "\(field) has an invalid length."
        case .invalidValue(let field):
            return "\(field) has an invalid value."
        case .valuesDontMatch(let field):
            return "\(field) values don't match."
        case .maxValueExceeded(let field):
            return "\(field) exceeds the maximum allowed value."
        case .minValueNotMet(let field):
            return "\(field) is below the minimum required value."
        }
    }
}
