
import SwiftUI

extension View {
    public func underlineTextField(_ colorScheme: ColorScheme = .light) -> some View {
        self
            .padding(.vertical, 10)
            .overlay(Rectangle().frame(height: 2).padding(.top, 35))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .padding(10)
    }
}

