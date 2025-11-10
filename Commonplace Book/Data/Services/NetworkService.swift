//
//  NetworkService.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import Combine

/// Error types that can occur during networking operations
enum NetworkError: Error, LocalizedError {
    /// Invalid URL
    case invalidURL
    /// No data received
    case noData
    /// Decoding error
    case decodingError(Error)
    /// Invalid response
    case invalidResponse
    /// Server error with status code
    case serverError(Int, Data?)
    /// Network error with underlying error
    case networkError(Error)
    /// Request timed out
    case timeoutError
    /// Request was cancelled
    case cancelled
    /// No internet connection
    case noInternetConnection
    /// SSL certificate validation failed
    case certificateError
    /// Too many requests (rate limited)
    case rateLimited(retryAfter: TimeInterval?)
    
    /// User-friendly error description
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid. Please check the address and try again."
        case .noData:
            return "No data was received from the server."
        case .decodingError(let error):
            return "Failed to process the response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .serverError(let statusCode, _):
            return serverErrorMessage(for: statusCode)
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeoutError:
            return "The request timed out. Please check your connection and try again."
        case .cancelled:
            return "The request was cancelled."
        case .noInternetConnection:
            return "No internet connection. Please check your connection and try again."
        case .certificateError:
            return "Secure connection failed. There might be a problem with the server's security certificate."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Too many requests. Please try again in \(Int(seconds)) seconds."
            }
            return "Too many requests. Please try again later."
        }
    }
    
    /// Provides a recovery suggestion for the error
    var recoverySuggestion: String? {
        switch self {
        case .noInternetConnection:
            return "Check your Wi-Fi or cellular connection."
        case .timeoutError:
            return "The server might be experiencing high traffic. Try again later."
        case .serverError(let statusCode, _):
            return statusCode >= 500 ? "The server is experiencing issues. Please try again later." : "Check your request parameters."
        default:
            return nil
        }
    }
    
    /// Returns the server error message for a specific status code
    private func serverErrorMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "Bad request. The server couldn't understand the request."
        case 401:
            return "Unauthorized. Please log in again."
        case 403:
            return "Forbidden. You don't have permission to access this resource."
        case 404:
            return "Resource not found."
        case 429:
            return "Too many requests. Please try again later."
        case 500...599:
            return "Server error (\(statusCode)). The server encountered an error."
        default:
            return "Server error with status code: \(statusCode)"
        }
    }
    
    /// Determines if the error is retryable
    var isRetryable: Bool {
        switch self {
        case .timeoutError, .networkError, .noInternetConnection:
            return true
        case .serverError(let code, _):
            return code >= 500 // Only retry server errors
        default:
            return false
        }
    }
}

/// HTTP method for network requests
enum HTTPMethod: String {
    /// GET method
    case get = "GET"
    /// POST method
    case post = "POST"
    /// PUT method
    case put = "PUT"
    /// DELETE method
    case delete = "DELETE"
    /// PATCH method
    case patch = "PATCH"
}

/// Protocol for network service
protocol NetworkServiceProtocol {
    /// Performs a network request
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: The HTTP method
    ///   - parameters: The request parameters
    ///   - headers: The request headers
    ///   - body: The request body
    ///   - retryCount: Number of times to retry on failure
    /// - Returns: A publisher with the response data or an error
    func request(
        endpoint: String,
        method: HTTPMethod,
        parameters: [String: String]?,
        headers: [String: String]?,
        body: Data?,
        retryCount: Int
    ) -> AnyPublisher<Data, NetworkError>
    
    /// Performs a network request and decodes the response
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: The HTTP method
    ///   - parameters: The request parameters
    ///   - headers: The request headers
    ///   - body: The request body
    ///   - retryCount: Number of times to retry on failure
    /// - Returns: A publisher with the decoded response or an error
    func requestDecodable<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: [String: String]?,
        headers: [String: String]?,
        body: Data?,
        retryCount: Int
    ) -> AnyPublisher<T, NetworkError>
    
    /// Cancels all pending requests
    func cancelAllRequests()
    
    /// Checks if the internet connection is available
    /// - Returns: True if internet is available, false otherwise
    func isInternetAvailable() -> Bool
}

/// Network service for performing API requests
class NetworkService: NetworkServiceProtocol {
    /// Shared instance of the network service
    static let shared = NetworkService()
    
    /// URL session for network requests
    private let session: URLSession
    
    /// JSON decoder for response parsing
    private let decoder: JSONDecoder
    
    /// Base URL for API requests
    private let baseURL: String
    
    /// Default headers for API requests
    private let defaultHeaders: [String: String]
    
    /// URL session task for certificate pinning
    private var sessionTask: URLSessionTask?
    
    /// Active sessions to keep track of and cancel
    private var activeSessions = Set<URLSessionTask>()
    
    /// Lock for thread-safe access to active sessions
    private let sessionsLock = NSLock()
    
    /// Initializes the network service
    /// - Parameters:
    ///   - baseURL: The base URL for API requests
    ///   - defaultHeaders: The default headers for API requests
    ///   - session: The URL session for network requests
    init(
        baseURL: String = Constants.API.baseURL,
        defaultHeaders: [String: String] = Constants.API.headers,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.session = session
        
        // Configure the decoder
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }
    
    /// Performs a network request
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: The HTTP method
    ///   - parameters: The request parameters
    ///   - headers: The request headers
    ///   - body: The request body
    ///   - retryCount: Number of times to retry on failure (default is 0)
    /// - Returns: A publisher with the response data or an error
    func request(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil,
        body: Data? = nil,
        retryCount: Int = 0
    ) -> AnyPublisher<Data, NetworkError> {
        // Check for internet connectivity
        if !isInternetAvailable() {
            return Fail(error: NetworkError.noInternetConnection).eraseToAnyPublisher()
        }
        
        // Build the URL
        guard var components = URLComponents(string: baseURL + endpoint) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        // Add query parameters
        if let parameters = parameters {
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = Constants.API.timeout
        
        // Add headers
        // First add default headers
        defaultHeaders.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Then add custom headers, which can override defaults
        headers?.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Add body if provided
        request.httpBody = body
        
        // Log the request
        Logger.info("Request: \(method.rawValue) \(url.absoluteString)", category: .network)
        
        return performRequest(request: request, retryCount: retryCount)
    }
    
    /// Performs the network request with retry logic
    /// - Parameters:
    ///   - request: The URLRequest to perform
    ///   - retryCount: Number of times to retry on failure
    /// - Returns: A publisher with the response data or an error
    private func performRequest(request: URLRequest, retryCount: Int) -> AnyPublisher<Data, NetworkError> {
        return session.dataTaskPublisher(for: request)
            .mapError { error -> NetworkError in
                // URLSession.DataTaskPublisher.Failure is already URLError
                let urlError = error
                switch urlError.code {
                case .notConnectedToInternet:
                    return .noInternetConnection
                case .timedOut:
                    return .timeoutError
                case .cancelled:
                    return .cancelled
                default:
                    return .networkError(error)
                }
            }
            .tryMap { [weak self] data, response -> Data in
                guard self != nil else {
                    throw NetworkError.cancelled
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                // Log the response
                Logger.info("Response: \(httpResponse.statusCode) for \(request.url?.absoluteString ?? "")", category: .network)
                
                // Check for rate limiting
                if httpResponse.statusCode == 429 {
                    let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? String
                    let retryTime = TimeInterval(retryAfter ?? "60") ?? 60
                    throw NetworkError.rateLimited(retryAfter: retryTime)
                }
                
                // Check for server errors
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.serverError(httpResponse.statusCode, data)
                }
                
                return data
            }
            .tryCatch { [weak self] (error: Error) -> AnyPublisher<Data, NetworkError> in
                guard let self = self, retryCount > 0 else {
                    if let networkError = error as? NetworkError {
                        throw networkError
                    } else {
                        throw NetworkError.networkError(error)
                    }
                }
                
                let networkError: NetworkError
                if let error = error as? NetworkError {
                    networkError = error
                } else {
                    networkError = .networkError(error)
                }
                
                // Only retry if the error is retryable
                guard networkError.isRetryable else {
                    throw networkError
                }
                
                // Calculate exponential backoff
                let delay = pow(2.0, Double(3 - retryCount)) + Double.random(in: 0...1)
                
                return Just(())
                    .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                    .flatMap { _ in
                        return self.performRequest(request: request, retryCount: retryCount - 1)
                    }
                    .eraseToAnyPublisher()
            }
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return .networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    /// Performs a network request and decodes the response
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: The HTTP method
    ///   - parameters: The request parameters
    ///   - headers: The request headers
    ///   - body: The request body
    ///   - retryCount: Number of times to retry on failure (default is 0)
    /// - Returns: A publisher with the decoded response or an error
    func requestDecodable<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: String]? = nil,
        headers: [String: String]? = nil,
        body: Data? = nil,
        retryCount: Int = 0
    ) -> AnyPublisher<T, NetworkError> {
        return request(
            endpoint: endpoint,
            method: method,
            parameters: parameters,
            headers: headers,
            body: body,
            retryCount: retryCount
        )
        .decode(type: T.self, decoder: decoder)
        .mapError { error in
            if let decodingError = error as? DecodingError {
                // Log decoding errors with more detail
                let context = self.extractDecodingContext(from: decodingError)
                Logger.error("Decoding error: \(context)", category: .network)
                return NetworkError.decodingError(decodingError)
            } else if let networkError = error as? NetworkError {
                return networkError
            } else {
                return NetworkError.networkError(error)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Cancels all pending requests
    func cancelAllRequests() {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }
        
        activeSessions.forEach { $0.cancel() }
        activeSessions.removeAll()
    }
    
    /// Checks if the internet connection is available
    /// - Returns: True if internet is available, false otherwise
    func isInternetAvailable() -> Bool {
        // This is a simplified check. In a real app, use Reachability or NWPathMonitor
        // For this template, we'll assume internet is available
        return true
    }
    
    // MARK: - Private Methods
    
    /// Adds a session task to the active sessions set
    /// - Parameter task: The URL session task to add
    private func addActiveSession(_ task: URLSessionTask) {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }
        
        activeSessions.insert(task)
    }
    
    /// Removes a session task from the active sessions set
    /// - Parameter task: The URL session task to remove
    private func removeActiveSession(_ task: URLSessionTask) {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }
        
        activeSessions.remove(task)
    }
    
    /// Extracts context information from a decoding error
    /// - Parameter error: The decoding error
    /// - Returns: A string with context information
    private func extractDecodingContext(from error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Key not found: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Value not found for type \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Type mismatch for type \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted: \(context.debugDescription), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        @unknown default:
            return "Unknown decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - URLSession Extension for Certificate Pinning

extension URLSession {
    /// Creates a session with certificate pinning
    /// - Parameter certificates: An array of certificates to pin
    /// - Returns: A URLSession configured with certificate pinning
    static func makeWithCertificatePinning(certificates: [Data]) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        
        let delegate = CertificatePinningDelegate(certificates: certificates)
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
}

/// URL session delegate for certificate pinning
class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    /// Pinned certificates
    private let certificates: [Data]
    
    /// Initializes the delegate with certificates
    /// - Parameter certificates: The certificates to pin
    init(certificates: [Data]) {
        self.certificates = certificates
        super.init()
    }
    
    /// Called when a challenge occurs during the connection
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Check if the challenge is server trust
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Check if certificate pinning is required for this server
        if certificates.isEmpty {
            // No certificate pinning for this server
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        
        // Get the server certificate data
        if let serverCertificateData = extractCertificateData(from: serverTrust) {
            // Check if the server certificate matches any of the pinned certificates
            if certificates.contains(serverCertificateData) {
                // Certificate matched
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        
        // Certificate validation failed
        Logger.error("Certificate pinning failed", category: .network)
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
    
    /// Extracts certificate data from server trust
    /// - Parameter serverTrust: The server trust object
    /// - Returns: The certificate data or nil if extraction failed
    private func extractCertificateData(from serverTrust: SecTrust) -> Data? {
        // Get the server's certificate
        if let serverCertificate = SecTrustCopyCertificateChain(serverTrust) {
            // Extract the data from the certificate
            return SecCertificateCopyData(serverCertificate as! SecCertificate) as Data
        }
        return nil
    }
}
