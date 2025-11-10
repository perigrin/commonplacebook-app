//
//  ErrorHandler.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import Combine
import SwiftUI

/// Error handler for managing and displaying errors
class ErrorHandler: ObservableObject {
    /// Shared instance of the error handler
    static let shared = ErrorHandler()
    
    /// Current error
    @Published var currentError: AppError?
    
    /// Error subject for publishing errors
    private let errorSubject = PassthroughSubject<AppError, Never>()
    
    /// Error publisher for subscribing to errors
    var errorPublisher: AnyPublisher<AppError, Never> {
        return errorSubject.eraseToAnyPublisher()
    }
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Set up subscription to error subject
        errorSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
    }
    
    /// Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Maximum number of retry attempts
    private let maxRetryAttempts = 3
    
    /// Retry count for each error
    private var retryCount: [String: Int] = [:]
    
    /// Handles an error
    /// - Parameter error: The error to handle
    private func handleError(_ error: AppError) {
        // Log the error
        switch error.logLevel {
        case .debug:
            Logger.debug("\(error.localizedDescription) \(error.recoverySuggestion ?? "")", category: .general)
        case .info:
            Logger.info("\(error.localizedDescription) \(error.recoverySuggestion ?? "")", category: .general)
        case .warning:
            Logger.warning("\(error.localizedDescription) \(error.recoverySuggestion ?? "")", category: .general)
        case .error:
            Logger.error("\(error.localizedDescription) \(error.recoverySuggestion ?? "")", category: .general)
        case .critical:
            Logger.critical("\(error.localizedDescription) \(error.recoverySuggestion ?? "")", category: .general)
        }
        
        // Set the current error
        currentError = error
        
        // Report the error to analytics
        reportErrorToAnalytics(error)
        
        // Check if we should retry
        if error.isRetryable {
            let errorId = error.id
            let currentCount = retryCount[errorId] ?? 0
            
            if currentCount < maxRetryAttempts {
                // Increment retry count
                retryCount[errorId] = currentCount + 1
                
                // Perform retry with exponential backoff
                let backoffDelay = pow(2.0, Double(currentCount)) + Double.random(in: 0...1)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + backoffDelay) { [weak self] in
                    self?.retryOperation(for: error)
                }
                
                return
            }
        }
        
        // Reset retry count if we're not retrying
        retryCount[error.id] = 0
    }
    
    /// Reports an error to analytics
    /// - Parameter error: The error to report
    private func reportErrorToAnalytics(_ error: AppError) {
        // In a real app, this would send the error to an analytics service
        // For this template, we'll just log it
        Logger.info("Reporting error to analytics: \(error.localizedDescription)", category: .analytics)
    }
    
    /// Retries an operation for an error
    /// - Parameter error: The error to retry
    private func retryOperation(for error: AppError) {
        // In a real app, this would retry the operation that failed
        // For this template, we'll just log it
        Logger.info("Retrying operation for error: \(error.localizedDescription)", category: .general)
        
        // Clear the current error
        currentError = nil
    }
    
    /// Handles an error
    /// - Parameter error: The error to handle
    func handle(_ error: Error) {
        // Convert to AppError if needed
        let appError = AppError.from(error)
        
        // Send to error subject
        errorSubject.send(appError)
    }
    
    /// Clears the current error
    func clearError() {
        currentError = nil
    }
}

/// Error alert modifier for SwiftUI views
struct ErrorAlertModifier: ViewModifier {
    /// Error handler
    @ObservedObject var errorHandler: ErrorHandler
    
    /// Alert is presented
    @Binding var isPresented: Bool
    
    /// Completion handler
    var completion: (() -> Void)?
    
    /// Modifies the view
    /// - Parameter content: The content to modify
    /// - Returns: The modified content
    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.localizedDescription ?? "An error occurred",
                isPresented: $isPresented,
                actions: {
                    Button("OK") {
                        errorHandler.clearError()
                        completion?()
                    }
                },
                message: {
                    if let suggestion = errorHandler.currentError?.recoverySuggestion {
                        Text(suggestion)
                    }
                }
            )
            .onChange(of: errorHandler.currentError) { newValue in
                isPresented = newValue != nil
            }
    }
}

/// Extension for SwiftUI View to add error handling
extension View {
    /// Adds error handling to the view
    /// - Parameters:
    ///   - errorHandler: The error handler
    ///   - isPresented: Binding to control alert presentation
    ///   - completion: Completion handler
    /// - Returns: The modified view
    func handleErrors(
        using errorHandler: ErrorHandler = ErrorHandler.shared,
        isPresented: Binding<Bool>,
        completion: (() -> Void)? = nil
    ) -> some View {
        self.modifier(ErrorAlertModifier(
            errorHandler: errorHandler,
            isPresented: isPresented,
            completion: completion
        ))
    }
}

/// Result extension for handling errors
extension Result {
    /// Handles errors with the error handler
    /// - Parameters:
    ///   - handler: The error handler
    ///   - transform: Transform function for success
    /// - Returns: Transformed success value or nil if error
    func handleError(
        with handler: ErrorHandler = ErrorHandler.shared,
        transform: (Success) -> Void
    ) {
        switch self {
        case .success(let value):
            transform(value)
        case .failure(let error):
            handler.handle(error)
        }
    }
}

/// Publisher extension for handling errors
extension Publisher {
    /// Handles errors with the error handler
    /// - Parameter handler: The error handler
    /// - Returns: A publisher that handles errors
    func handleError(with handler: ErrorHandler = ErrorHandler.shared) -> AnyPublisher<Output, Never> {
        return self.catch { error -> Empty<Output, Never> in
            handler.handle(error)
            return Empty()
        }
        .eraseToAnyPublisher()
    }
}
