// ABOUTME: SwiftUI error presentation service with user-friendly messages
// ABOUTME: Manages error alerts, toasts, and recovery actions for the app

import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Service for presenting errors to users in a friendly way
@MainActor
class ErrorPresenter: ObservableObject {

    // MARK: - Published State

    /// Current error being displayed
    @Published var currentError: PresentableError?

    /// Whether to show the error alert
    @Published var showError: Bool = false

    // MARK: - Error Presentation

    /// Present an error to the user
    /// - Parameter error: The error to present
    func present(_ error: Error) {
        let presentable = PresentableError(from: error)
        currentError = presentable
        showError = true

        // Log the error
        Logger.error(presentable.message, category: presentable.category)
    }

    /// Dismiss the current error
    func dismiss() {
        showError = false
        currentError = nil
    }

    // MARK: - Error Categorization

    /// Categorize an error for better user messaging
    private func categorize(_ error: Error) -> ErrorCategory {
        if let appError = error as? AppError {
            switch appError {
            case .network:
                return .network
            case .repository:
                return .data
            case .authentication:
                return .permission
            case .validation:
                return .validation
            case .general, .unknown:
                return .general
            }
        }

        if let repoError = error as? RepositoryError {
            return .data
        }

        if error is CancellationError {
            return .cancelled
        }

        return .general
    }
}

// MARK: - Presentable Error

/// Error formatted for user presentation
struct PresentableError: Identifiable {
    let id = UUID()
    let message: String
    let title: String
    let suggestion: String?
    let category: Logger.Category
    let recoveryAction: RecoveryAction?

    init(from error: Error) {
        // Get user-friendly message
        if let appError = error as? AppError {
            self.message = appError.localizedDescription
            self.suggestion = appError.recoverySuggestion

            switch appError {
            case .network:
                self.title = "Connection Error"
                self.category = .network
                self.recoveryAction = .retry
            case .repository:
                self.title = "Data Error"
                self.category = .database
                self.recoveryAction = .retry
            case .authentication:
                self.title = "Permission Required"
                self.category = .security
                self.recoveryAction = .openSettings
            case .validation:
                self.title = "Invalid Input"
                self.category = .general
                self.recoveryAction = nil
            case .general, .unknown:
                self.title = "Error"
                self.category = .general
                self.recoveryAction = .retry
            }
        } else if let repoError = error as? RepositoryError {
            self.message = repoError.errorDescription ?? "A data error occurred"
            self.title = "Data Error"
            self.category = .database
            self.suggestion = "Please try again. If the problem persists, restart the app."
            self.recoveryAction = .retry
        } else if error is CancellationError {
            self.message = "Operation was cancelled"
            self.title = "Cancelled"
            self.category = .general
            self.suggestion = nil
            self.recoveryAction = nil
        } else {
            self.message = error.localizedDescription
            self.title = "Error"
            self.category = .general
            self.suggestion = "Please try again."
            self.recoveryAction = .retry
        }
    }

    /// Custom error creation
    init(title: String, message: String, suggestion: String? = nil, category: Logger.Category = .general, recoveryAction: RecoveryAction? = nil) {
        self.title = title
        self.message = message
        self.suggestion = suggestion
        self.category = category
        self.recoveryAction = recoveryAction
    }
}

// MARK: - Error Category

enum ErrorCategory {
    case network
    case data
    case permission
    case validation
    case cancelled
    case general
}

// MARK: - Recovery Action

enum RecoveryAction {
    case retry
    case openSettings
    case contact
    case dismiss

    var label: String {
        switch self {
        case .retry:
            return "Try Again"
        case .openSettings:
            return "Open Settings"
        case .contact:
            return "Contact Support"
        case .dismiss:
            return "OK"
        }
    }

    var systemImage: String {
        switch self {
        case .retry:
            return "arrow.clockwise"
        case .openSettings:
            return "gear"
        case .contact:
            return "envelope"
        case .dismiss:
            return "checkmark"
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Present errors using an ErrorPresenter
    /// - Parameter presenter: The error presenter to use
    /// - Returns: A view with error presentation
    func errorAlert(_ presenter: ObservedObject<ErrorPresenter>) -> some View {
        self.alert(
            presenter.wrappedValue.currentError?.title ?? "Error",
            isPresented: presenter.projectedValue.showError,
            presenting: presenter.wrappedValue.currentError
        ) { error in
            // Primary action button
            if let action = error.recoveryAction {
                Button(action.label) {
                    handleRecoveryAction(action)
                    presenter.wrappedValue.dismiss()
                }
            }

            // Cancel button
            Button("Dismiss", role: .cancel) {
                presenter.wrappedValue.dismiss()
            }
        } message: { error in
            VStack(alignment: .leading, spacing: 8) {
                Text(error.message)

                if let suggestion = error.suggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func handleRecoveryAction(_ action: RecoveryAction) {
        switch action {
        case .retry:
            // Caller should implement retry logic
            break
        case .openSettings:
            #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #elseif os(macOS)
            if let url = URL(string: "x-apple.systempreferences:") {
                NSWorkspace.shared.open(url)
            }
            #endif
        case .contact:
            // Open mail or support URL
            break
        case .dismiss:
            break
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension ErrorPresenter {
    static func preview(with error: PresentableError) -> ErrorPresenter {
        let presenter = ErrorPresenter()
        presenter.currentError = error
        presenter.showError = true
        return presenter
    }
}
#endif
