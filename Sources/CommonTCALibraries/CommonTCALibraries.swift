
import Foundation
import ComposableArchitecture

struct CommonTCALibraries {}

extension Array where Element: Identifiable {
    public func toIdentifiedArray() -> IdentifiedArrayOf<Element> {
        IdentifiedArrayOf(uniqueElements: self)
    }
}

extension IdentifiedArrayOf where Element: Identifiable {
    public func isLastItem(_ item: Element) -> Bool {
        self.last?.id == item.id
    }
}
