import SwiftUI

/// Borderless password entry for the unlock field card: macOS Password AutoFill field, SecureField on iOS.
struct UnlockPasswordField: View {
    @Binding var text: String
    var showsPlaintext: Bool
    var placeholder: String = "Password"

    var body: some View {
        #if os(macOS)
        AutofillPasswordField(
            text: $text,
            showsPlaintext: showsPlaintext,
            placeholder: placeholder
        )
        #else
        Group {
            if showsPlaintext {
                TextField(placeholder, text: $text)
            } else {
                SecureField(placeholder, text: $text)
            }
        }
        .textContentType(.password)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        #endif
    }
}
