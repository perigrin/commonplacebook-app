//
//  Logger.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import os.log
import Combine

/// Logger provides a unified logging interface for the application
enum Logger {
    /// Log categories
    enum Category: String, CaseIterable {
        /// General app logs
        case general
        /// Network-related logs
        case network
        /// Database-related logs
        case database
        /// UI-related logs
        case ui
        /// Analytics-related logs
        case analytics
        /// User-related logs
        case user
        /// Security-related logs
        case security
        /// Performance-related logs
        case performance
        /// Embedding-related logs
        case embedding
        /// Git-related logs
        case git
    }
    
    /// Log levels
    enum Level: Int, Comparable {
        /// Debug logs for verbose development information
        case debug = 0
        /// Info logs for general information
        case info = 1
        /// Warning logs for potential issues
        case warning = 2
        /// Error logs for actual errors
        case error = 3
        /// Critical logs for severe errors
        case critical = 4
        
        /// Compare log levels
        static func < (lhs: Logger.Level, rhs: Logger.Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        /// Human-readable string representation
        var description: String {
            switch self {
            case .debug:
                return "DEBUG"
            case .info:
                return "INFO"
            case .warning:
                return "WARNING"
            case .error:
                return "ERROR"
            case .critical:
                return "CRITICAL"
            }
        }
        
        /// Convert to OSLogType
        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            case .critical:
                return .fault
            }
        }
    }
    
    /// Minimum log level to display
    static var minimumLogLevel: Level = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()
    
    /// Subject for log entries to enable subscribing to logs
    static let logPublisher = PassthroughSubject<LogEntry, Never>()
    
    /// Log entry structure
    struct LogEntry {
        /// The log message
        let message: String
        
        /// The log level
        let level: Level
        
        /// The log category
        let category: Category
        
        /// The file where the log was created
        let file: String
        
        /// The function where the log was created
        let function: String
        
        /// The line number where the log was created
        let line: Int
        
        /// The timestamp of the log entry
        let timestamp: Date
        
        /// Convert the log entry to a formatted string
        var formattedString: String {
            let fileURL = URL(fileURLWithPath: file)
            let fileName = fileURL.lastPathComponent
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return "[\(dateFormatter.string(from: timestamp))][\(level.description)][\(category.rawValue)] \(fileName):\(line) - \(function) | \(message)"
        }
    }
    
    // MARK: - Logging methods
    
    /// Log a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The file name
    ///   - function: The function name
    ///   - line: The line number
    static func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The file name
    ///   - function: The function name
    ///   - line: The line number
    static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The file name
    ///   - function: The function name
    ///   - line: The line number
    static func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The file name
    ///   - function: The function name
    ///   - line: The line number
    static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Log a critical message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: The file name
    ///   - function: The function name
    ///   - line: The line number
    static func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error object
    /// - Parameters:
    ///   - error: The error to log
    ///   - category: The log category
    ///   - file: The file name
    ///   - function: The function name
    ///   - line: The line number
    static func log(error: Error, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let nsError = error as NSError
        let userInfo = nsError.userInfo.description
        
        // Log the error
        log("Error: \(nsError.localizedDescription) (Code: \(nsError.code), Domain: \(nsError.domain), UserInfo: \(userInfo))", 
            level: .error, 
            category: category, 
            file: file, 
            function: function, 
            line: line)
    }
    
    /// Measure the performance of a block of code
    /// - Parameters:
    ///   - description: A description of the operation being measured
    ///   - category: The log category
    ///   - file: The file name
    ///   - function: The function name
    ///   - line: The line number
    ///   - block: The block of code to measure
    /// - Returns: The result of the block
    @discardableResult
    static func measure<T>(_ description: String, category: Category = .performance, file: String = #file, function: String = #function, line: Int = #line, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let end = CFAbsoluteTimeGetCurrent()
        let duration = (end - start) * 1000 // Convert to milliseconds
        
        // Log the performance measurement
        log("\(description) completed in \(String(format: "%.2f", duration))ms", level: .debug, category: category, file: file, function: function, line: line)
        
        return result
    }
    
    /// Subscribe to log entries
    /// - Parameter onReceive: The closure to call when a log entry is received
    /// - Returns: A cancellable to unsubscribe
    static func subscribe(onReceive: @escaping (LogEntry) -> Void) -> AnyCancellable {
        return logPublisher.sink(receiveValue: onReceive)
    }
    
    // MARK: - Private methods
    
    /// Log a message with the specified level and category
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - category: The log category
    ///   - file: The file name
    ///   - function: The function name
    ///   - line: The line number
    private static func log(_ message: String, level: Level, category: Category, file: String, function: String, line: Int) {
        // Skip logs below the minimum level
        guard level >= minimumLogLevel else { return }
        
        // Create the log entry
        let entry = LogEntry(
            message: message,
            level: level,
            category: category,
            file: file,
            function: function,
            line: line,
            timestamp: Date()
        )
        
        // Log to console in debug builds
        #if DEBUG
        print(entry.formattedString)
        #endif
        
        // Log to system log
        let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.template.app", category: category.rawValue)
        os_log("%{public}@", log: osLog, type: level.osLogType, message)
        
        // Send to log publisher
        logPublisher.send(entry)
        
        // Log to file in release builds
        #if !DEBUG
        appendToLogFile(entry: entry)
        #endif
    }
    
    /// Append a log entry to the log file
    /// - Parameter entry: The log entry to append
    private static func appendToLogFile(entry: LogEntry) {
        guard let logFileURL = getLogFileURL() else { return }
        
        // Ensure directory exists
        createLogDirectoryIfNeeded()
        
        // Append to log file
        let logString = entry.formattedString + "\n"
        if let data = logString.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL, options: .atomicWrite)
            }
        }
        
        // Rotate logs if needed
        rotateLogsIfNeeded()
    }
    
    /// Get the URL for the log file
    /// - Returns: The log file URL
    private static func getLogFileURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let logsDirectory = documentsDirectory.appendingPathComponent("Logs")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return logsDirectory.appendingPathComponent("app_log_\(dateString).log")
    }
    
    /// Create the log directory if it doesn't exist
    private static func createLogDirectoryIfNeeded() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let logsDirectory = documentsDirectory.appendingPathComponent("Logs")
        
        if !FileManager.default.fileExists(atPath: logsDirectory.path) {
            try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Rotate logs if needed
    private static func rotateLogsIfNeeded() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let logsDirectory = documentsDirectory.appendingPathComponent("Logs")
        
        // Get all log files
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }
        
        // Check total size of log files
        let totalSize = fileURLs.reduce(0) { result, url in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let fileSize = attributes[.size] as? Int else { return result }
            return result + fileSize
        }
        
        // If total size is over 50MB, remove the oldest logs
        let maxSize = 50 * 1024 * 1024 // 50MB
        if totalSize > maxSize {
            // Sort files by modification date
            let sortedFiles = fileURLs.compactMap { url -> (URL, Date)? in
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let modificationDate = attributes[.modificationDate] as? Date else { return nil }
                return (url, modificationDate)
            }.sorted { $0.1 < $1.1 }
            
            // Remove oldest files until we're under the limit
            var currentSize = totalSize
            for (url, _) in sortedFiles {
                guard currentSize > maxSize else { break }
                
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let fileSize = attributes[.size] as? Int {
                    try? FileManager.default.removeItem(at: url)
                    currentSize -= fileSize
                }
            }
        }
    }
}

// MARK: - Log View

#if DEBUG
import SwiftUI

/// A view that displays log messages
struct LogView: View {
    @State private var logs: [Logger.LogEntry] = []
    @State private var selectedCategories: Set<Logger.Category> = Set(Logger.Category.allCases)
    @State private var selectedLevel: Logger.Level = .debug
    @State private var searchText = ""
    
    private var filteredLogs: [Logger.LogEntry] {
        logs.filter { entry in
            (selectedCategories.contains(entry.category) || selectedCategories.isEmpty) &&
            entry.level >= selectedLevel &&
            (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    @State private var cancellable: AnyCancellable?
    
    var body: some View {
        VStack {
            HStack {
                Text("Log Viewer")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear") {
                    logs.removeAll()
                }
            }
            .padding()
            
            HStack {
                Text("Level:")
                Picker("Level", selection: $selectedLevel) {
                    Text("Debug").tag(Logger.Level.debug)
                    Text("Info").tag(Logger.Level.info)
                    Text("Warning").tag(Logger.Level.warning)
                    Text("Error").tag(Logger.Level.error)
                    Text("Critical").tag(Logger.Level.critical)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Logger.Category.allCases, id: \.rawValue) { category in
                        Toggle(category.rawValue.capitalized, isOn: Binding(
                            get: { selectedCategories.contains(category) },
                            set: { isOn in
                                if isOn {
                                    selectedCategories.insert(category)
                                } else {
                                    selectedCategories.remove(category)
                                }
                            }
                        ))
                        .toggleStyle(ButtonToggleStyle())
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)
            }
            
            TextField("Search logs...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            List {
                ForEach(filteredLogs, id: \.timestamp) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("[\(entry.level.description)]")
                                .font(.caption)
                                .foregroundColor(colorForLevel(entry.level))
                            
                            Text("[\(entry.category.rawValue)]")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formattedTime(for: entry.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(entry.message)
                            .font(.body)
                            .lineLimit(nil)
                        
                        HStack {
                            Text("\(URL(fileURLWithPath: entry.file).lastPathComponent):\(entry.line)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(entry.function)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            // Subscribe to log publisher
            cancellable = Logger.subscribe { entry in
                DispatchQueue.main.async {
                    self.logs.append(entry)
                    
                    // Keep only the last 1000 logs
                    if self.logs.count > 1000 {
                        self.logs.removeFirst(self.logs.count - 1000)
                    }
                }
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }
    
    /// Format the timestamp for display
    /// - Parameter date: The date to format
    /// - Returns: A formatted time string
    private func formattedTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    /// Get a color for a log level
    /// - Parameter level: The log level
    /// - Returns: The color for the level
    private func colorForLevel(_ level: Logger.Level) -> Color {
        switch level {
        case .debug:
            return .gray
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
}

/// Toggle style for the category filters
struct ButtonToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(configuration.isOn ? .white : .primary)
                .background(configuration.isOn ? Color.blue : Color.secondary.opacity(0.2))
                .cornerRadius(8)
        }
    }
}

#Preview {
    LogView()
}
#endif
