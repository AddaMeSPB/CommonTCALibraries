import Foundation
import os

/// Logs app info using the newest Swift unified logging APIs.
///
/// Reference:
///  - [Explore logging in Swift (WWDC20)](https://developer.apple.com/wwdc20/10168)
///  - [Unified Logging](https://developer.apple.com/documentation/os/logging)
///  - [OSLog](https://developer.apple.com/documentation/os/oslog)
///  - [Logger](https://developer.apple.com/documentation/os/logger)
public struct LoggerKit {
    public enum Category: String, Codable, Equatable {
        case `default`
        // All logs related to tracking and analytics.
        case statistics
    }

    // MARK: - Properties

    /// Default values used by the `LoggerKit`.
    public struct Defaults {
        public static let subsystem = Bundle.main.bundleIdentifier ?? "LoggerKit"
        public static let category: Category = .default
        public static let isPrivate = false
    }

    // MARK: - Private Properties

    private let logger: Logger

    // MARK: - Lifecycle

    /// Creates an `LoggerKit` instance.
    ///
    /// - Parameters:
    ///   - subsystem: `String`. Organizes large topic areas within the app or apps. For example, you might define
    ///   a subsystem for each process that you create. The default is `Bundle.main.bundleIdentifier ?? "LoggerKit"`.
    ///   - category: `String`. Within a `subsystem`, you define categories to further distinguish parts of that
    ///   subsystem. For example, if you used a single subsystem for your app, you might create separate categories for
    ///   model code and user-interface code. In a game, you might use categories to distinguish between physics, AI,
    ///   world simulation, and rendering. The default is `default`.
    public init(subsystem: String = Defaults.subsystem, category: Category = .default) {
        self.logger = Logger(subsystem: subsystem, category: category.rawValue)
    }
}

// MARK: - Interface

public extension LoggerKit {

    /// Logs a string interpolation at the given level, along with file name, line number, and function name.
    ///
    /// Notice that `.debug` won't work with simulators (nothing is shown in the Console app for this level),
    /// but works fine with physical devices. This is a known issue:
    /// https://stackoverflow.com/a/58814535/584548
    ///
    /// - Parameters:
    ///   - level: `OSLogType`; default is `.debug`.
    ///   - message: The `String` to be logged.
    ///   - isPrivate: Sets the `OSLogPrivacy` to be used by the function. `true` means `.private`;
    ///   `false` means `.public`. The default is `false`.
    ///   - file: The file name where the log message is generated; automatically filled by the compiler.
    ///   - line: The line number where the log message is generated; automatically filled by the compiler.
    ///   - function: The function name where the log message is generated; automatically filled by the compiler.
    func log(
        level: OSLogType = .debug,
        _ message: String,
        isPrivate: Bool = Defaults.isPrivate,
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "\(fileName):\(line) - \(function) - \(message)"
        if isPrivate {
            logger.log(level: level, "\(logMessage, privacy: .private)")
        } else {
            logger.log(level: level, "\(logMessage, privacy: .public)")
        }
    }
}

// MARK: - Error Handling

public extension LoggerKit {

    /// Logs an error along with file name, line number, and function name.
    ///
    /// - Parameters:
    ///   - error: The `Error` to be logged.
    ///   - level: `OSLogType`; default is `.error`.
    ///   - message: An optional additional message to be logged along with the error.
    ///   - file: The file name where the error occurred; automatically filled by the compiler.
    ///   - line: The line number where the error occurred; automatically filled by the compiler.
    ///   - function: The function name where the error occurred; automatically filled by the compiler.
    func logError(
        _ error: Error,
        level: OSLogType = .error,
        message: String? = nil,
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        let errorMessage: String
        if let message = message {
            errorMessage = "\(message) - \(error.localizedDescription)"
        } else {
            errorMessage = error.localizedDescription
        }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "\(fileName):\(line) - \(function) - \(errorMessage)"
        logger.log(level: level, "\(logMessage, privacy: .public)")
    }
}


// MARK: Shared instance of AppLogger
public let sharedLogger = LoggerKit()

/// How do use
/// import LoggerExtensionsKit

// Example usage in some library file
// sharedLogger.log(message: "This is a log message.")
