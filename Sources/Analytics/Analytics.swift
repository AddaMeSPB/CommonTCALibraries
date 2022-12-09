import Foundation

public enum Log {
    enum LogLevel {
        case info
        case warning
        case error

        fileprivate var prefix: String {
            switch self {
            case .info:    return "INFO"
            case .warning: return "WARN ⚠️"
            case .error:   return "ERROR ❌"
            }
        }
    }

    struct Context {
        let file: String
        let function: String
        let line: Int
        var description: String {
            return "\((file as NSString).lastPathComponent):\(line) \(function)"
        }
    }

    public static func info(_ str: StaticString, shouldLogContext: Bool = true, file: String = #file, function: String = #function, line: Int = #line) {
        let context = Context(file: file, function: function, line: line)
        Log.handleLog(level: .info, str: str.description, shouldLogContext: shouldLogContext, context: context)
    }

    public static func warning(_ str: StaticString, shouldLogContext: Bool = true, file: String = #file, function: String = #function, line: Int = #line) {
        let context = Context(file: file, function: function, line: line)
        Log.handleLog(level: .warning, str: str.description, shouldLogContext: shouldLogContext, context: context)
    }

    public static func error(_ str: StaticString, shouldLogContext: Bool = true, file: String = #file, function: String = #function, line: Int = #line) {
        let context = Context(file: file, function: function, line: line)
        Log.handleLog(level: .error, str: str.description, shouldLogContext: shouldLogContext, context: context)
    }

    fileprivate static func handleLog(level: LogLevel, str: String, shouldLogContext: Bool, context: Context) {
        #if DEBUG
            let logComponents = ["[\(level.prefix)]", str]

            var fullString = logComponents.joined(separator: " ")
            if shouldLogContext {
                fullString += " ➜ \(context.description)"
            }


            print(fullString)
        #endif
    }

}
