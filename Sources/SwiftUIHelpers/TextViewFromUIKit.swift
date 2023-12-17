
import Foundation
import SwiftUI

public struct TextViewFromUIKit: UIViewRepresentable {

    @Binding var text: String
    var font: UIFont
    var maxHeight: Int

    public init(
        text: Binding<String>,
        font: UIFont = UIFont.preferredFont(forTextStyle: .title2),
        maxHeight: Int = 50
    ) {
        self._text = text
        self.font = font
        self.maxHeight = maxHeight
    }

    public func makeUIView(context: UIViewRepresentableContext<TextViewFromUIKit>) -> UITextView {
        let textView = UIKitTextView()

        textView.delegate = context.coordinator

        return textView
    }

    public func updateUIView(_ textView: UITextView, context: UIViewRepresentableContext<TextViewFromUIKit>) {
            textView.text = self.text
            textView.backgroundColor = .clear
            textView.font = self.font

            textView.textColor =  UIColor { tc in
                 switch tc.userInterfaceStyle {
                 case .dark:
                     return UIColor.white
                 default:
                     return UIColor.black
                 }
             }

    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }

    final private class UIKitTextView: UITextView {
        override var contentSize: CGSize {
            didSet {
                invalidateIntrinsicContentSize()
            }
        }

        override var intrinsicContentSize: CGSize {
            // contentSize.height
            // Or use e.g. `min(contentSize.height, 150)` if you want to restrict max height
            CGSize(width: UIView.noIntrinsicMetric, height: min(contentSize.height, 80))
        }
        
    }

    final public class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        public func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}

