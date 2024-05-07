import SwiftUI
import PhoneNumberKit

public struct iCountryField: UIViewControllerRepresentable {
    @Binding public var selectedCountry: String
    @Binding public var isPresented: Bool

    public init(selectedCountry: Binding<String>, isPresented: Binding<Bool>) {
        self._selectedCountry = selectedCountry
        self._isPresented = isPresented
    }


    public func makeUIViewController(context: Context) -> UINavigationController {
            let phoneNumberKit = PhoneNumberKit()
            let viewController = CountryCodePickerViewController(phoneNumberKit: phoneNumberKit, options: nil)
            viewController.delegate = context.coordinator
            let navigationController = UINavigationController(rootViewController: viewController)
            return navigationController
        }

    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // update it as needed
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, CountryCodePickerDelegate {
        var parent: iCountryField

        init(_ parent: iCountryField) {
            self.parent = parent
        }

        public func countryCodePickerViewControllerDidPickCountry(_ country: CountryCodePickerViewController.Country) {
            parent.selectedCountry = country.name
            parent.isPresented = false
        }
    }
}

