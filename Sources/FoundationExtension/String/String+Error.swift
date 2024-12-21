
import Foundation

/// Easily throw generic errors with a text description.
extension String: @retroactive Error {}

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
}
