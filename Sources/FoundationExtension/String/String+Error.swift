
import Foundation

/// Easily throw generic errors with a text description.
extension String: Error {}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
