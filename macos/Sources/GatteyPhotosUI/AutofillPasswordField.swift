#if os(macOS)
import AppKit
import SwiftUI

/// Password field that participates in macOS Password AutoFill (iCloud Keychain, 1Password, etc.).
struct AutofillPasswordField: NSViewRepresentable {
    @Binding var text: String
    var showsPlaintext: Bool
    var placeholder: String = "Password"

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> AutofillPasswordContainerView {
        let container = AutofillPasswordContainerView()
        container.setField(
            secure: !showsPlaintext,
            placeholder: placeholder,
            text: text,
            coordinator: context.coordinator
        )
        return container
    }

    func updateNSView(_ container: AutofillPasswordContainerView, context: Context) {
        container.setField(
            secure: !showsPlaintext,
            placeholder: placeholder,
            text: text,
            coordinator: context.coordinator
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AutofillPasswordContainerView, context: Context) -> CGSize? {
        let height = max(proposal.height ?? 0, nsView.intrinsicContentSize.height)
        guard let width = proposal.width, width > 0, width.isFinite else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}

final class AutofillPasswordContainerView: NSView {
    private var field: NSTextField?
    private var isSecure = true

    /// Height of a bordered rounded-bezel field at regular control size (matches SwiftUI `.roundedBorder`).
    private static let borderedFieldHeight: CGFloat = {
        let probe = NSTextField(string: "")
        probe.isBordered = true
        probe.isBezeled = true
        probe.bezelStyle = .roundedBezel
        probe.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        probe.controlSize = .regular
        return ceil(probe.intrinsicContentSize.height)
    }()

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.borderedFieldHeight)
    }

    func setField(
        secure: Bool,
        placeholder: String,
        text: String,
        coordinator: AutofillPasswordField.Coordinator
    ) {
        if let field, isSecure == secure, field.placeholderString == placeholder {
            if field.stringValue != text {
                field.stringValue = text
            }
            return
        }

        let preserved = field?.stringValue ?? text
        let wasFirstResponder = field?.window?.firstResponder === field?.currentEditor() || field?.window?.firstResponder === field

        field?.removeFromSuperview()
        let newField = Self.makeField(secure: secure, placeholder: placeholder)
        newField.stringValue = preserved
        newField.delegate = coordinator
        addSubview(newField)
        newField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newField.leadingAnchor.constraint(equalTo: leadingAnchor),
            newField.trailingAnchor.constraint(equalTo: trailingAnchor),
            newField.centerYAnchor.constraint(equalTo: centerYAnchor),
            newField.heightAnchor.constraint(equalToConstant: Self.borderedFieldHeight),
        ])
        field = newField
        isSecure = secure

        if wasFirstResponder {
            window?.makeFirstResponder(newField)
        }
    }

    private static func makeField(secure: Bool, placeholder: String) -> NSTextField {
        let field: NSTextField = secure ? NSSecureTextField(string: "") : NSTextField(string: "")
        field.placeholderString = placeholder
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.controlSize = .regular
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.maximumNumberOfLines = 1
        field.usesSingleLineMode = true
        field.contentType = .password
        field.autoresizingMask = [.width]
        field.setContentHuggingPriority(.required, for: .vertical)
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        return field
    }
}
#endif
