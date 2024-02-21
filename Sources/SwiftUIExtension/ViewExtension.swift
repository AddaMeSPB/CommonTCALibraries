import SwiftUI

extension View {

  @ViewBuilder public func listRowSeparatorHidden() -> some View {
    if #available(iOS 15.0, *) {
      self.listRowSeparator(.hidden)
    } else { // ios 14
      self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .listRowInsets(EdgeInsets(top: -1, leading: 16, bottom: -1, trailing: 16))
          .background(Color(.systemBackground))
    }
  }

  @ViewBuilder public func stackNavigationViewStyle() -> some View {
    if #available(iOS 15.0, *) {
      self.navigationViewStyle(.stack)
    } else {
      self.navigationViewStyle(StackNavigationViewStyle())
    }
  }
}


extension View {
    @available(iOS, introduced: 16, deprecated: 17)
    @available(macOS, introduced: 13, deprecated: 14)
    @available(tvOS, introduced: 16, deprecated: 17)
    @available(watchOS, introduced: 9, deprecated: 10)
    @ViewBuilder
    public func navigationDestinationWrapper<D: Hashable, C: View>(
        item: Binding<D?>,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View {
        navigationDestination(isPresented: item.isPresented) {
            if let item = item.wrappedValue {
                destination(item)
            }
        }
    }
}

fileprivate extension Optional where Wrapped: Hashable {
  var isPresented: Bool {
    get { self != nil }
    set { if !newValue { self = nil } }
  }
}
