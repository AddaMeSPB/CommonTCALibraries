import Foundation

// MARK: - Utility

extension NSDataDetector {
    public struct CheckingType: OptionSet {
        public let rawValue: UInt64

        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        private init(_ type: NSTextCheckingResult.CheckingType) {
            self.rawValue = type.rawValue
        }

        public static let date = Self(.date)
        public static let address = Self(.address)
        public static let link = Self(.link)
        public static let phoneNumber = Self(.phoneNumber)
        public static let transitInformation = Self(.transitInformation)
    }

    public struct Result {
        public let range: Range<String.Index>
        public let type: ResultType

        public enum ResultType {
            case url(URL)
            case email(email: String, url: URL)
            case phoneNumber(String)
            case address(components: [NSTextCheckingKey: String])
            case date(Date)
        }
    }
}

extension NSDataDetector.CheckingType {
    public static let all: Self = [.date, .address, .link, .phoneNumber, .transitInformation]
}

extension NSDataDetector {
    public convenience init(types: CheckingType) {
        try! self.init(types: types.rawValue)
    }

    public func matches(
        in string: String,
        options: NSRegularExpression.MatchingOptions = []
    ) -> [Result] {
        let range = string.startIndex..<string.endIndex
        return matches(in: string, options: options, range: range)
    }

    public func matches(
        in string: String,
        options: NSRegularExpression.MatchingOptions = [],
        range: Range<String.Index>
    ) -> [Result] {
        let nsRange = NSRange(range, in: string)
        let processMatch = { self.processMatch($0, range: range) }
        return matches(in: string, options: options, range: nsRange)
            .compactMap(processMatch)
    }

    public func enumerateMatches(
        in string: String,
        options: NSRegularExpression.MatchingOptions = [],
        using block: (Result?, NSRegularExpression.MatchingFlags, inout Bool) -> Void
    ) {
        let range = string.startIndex..<string.endIndex
        enumerateMatches(in: string, options: options, range: range, using: block)
    }

    public func enumerateMatches(
        in string: String,
        options: NSRegularExpression.MatchingOptions = [],
        range: Range<String.Index>,
        using block: (Result?, NSRegularExpression.MatchingFlags, inout Bool) -> Void
    ) {
        let nsRange = NSRange(range, in: string)
        enumerateMatches(in: string, options: options, range: nsRange) { (result, flags, _stop) in
            var stop = false
            let result: Result? = result.flatMap {
                guard let range = Range($0.range, in: string) else { return nil }
                return processMatch($0, range: range)
            }
            block(result, flags, &stop)
            if stop { _stop.pointee = true }
        }
    }
}

private extension NSDataDetector {
    private func processMatch(
        _ match: NSTextCheckingResult,
        range: Range<String.Index>
    ) -> Result? {
        switch match.resultType {
        case .address:
            guard let components = match.addressComponents else { return nil }
            return .init(range: range, type: .address(components: components))

        case .date:
            guard let date = match.date else { return nil }
            return .init(range: range, type: .date(date))

        case .link:
            guard let url = match.url else { return nil }

            if url.absoluteString.hasPrefix("mailto:") {
                let email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                return .init(range: range, type: .email(email: email, url: url))
            } else {
                return .init(range: range, type: .url(url))
            }

        case .phoneNumber:
            guard let number = match.phoneNumber else { return nil }
            return .init(range: range, type: .phoneNumber(number))

        default:
            return nil
        }
    }
}
