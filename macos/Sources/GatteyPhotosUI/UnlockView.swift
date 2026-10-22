import GatteyPhotosCore
import SwiftUI

private let unlockFieldRowInset: CGFloat = 16

private enum UnlockField: Hashable {
    case name
    case password
}

struct UnlockView: View {
    @Environment(AppChromeState.self) private var chrome
    @Environment(GalleryStore.self) private var store
    @Environment(AppSession.self) private var session
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var displayName = AppSettings.defaultDisplayName
    @State private var password = ""
    @State private var bloomin8SetupText = ""
    @State private var showsFrameSetup = false
    @State private var showBloomin8Help = false
    @State private var showPassword = false
    @State private var showPasswordHelp = false
    @State private var isUnlocking = false
    @FocusState private var focusedField: UnlockField?

    private var isSideBySide: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(UnlockGlassBackground())
            .background(TransparentWindowConfigurator())
            #if os(macOS)
            .toolbarBackground(.hidden, for: .windowToolbar)
            #endif
            .onAppear {
                let savedName = store.settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !savedName.isEmpty {
                    displayName = savedName
                }
                if chrome.initialView == .unlockHelp {
                    showsFrameSetup = true
                    showBloomin8Help = true
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isSideBySide {
            GeometryReader { geo in
                ScrollView {
                    HStack(alignment: .center, spacing: UnlockLayout.regularColumnSpacing) {
                        UnlockWelcomePhotoPanel(framedHeight: UnlockLayout.regularFramedHeight)
                        formColumn
                            .frame(width: UnlockLayout.formColumnWidth)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        } else {
            ScrollView {
                VStack(spacing: 28) {
                    UnlockWelcomePhotoPanel(
                        framedHeight: UnlockLayout.compactFramedHeight,
                        chromeScale: UnlockLayout.compactChromeScale
                    )
                    formColumn
                }
                .padding(.horizontal, 20)
                .padding(.top, UnlockLayout.compactTopPadding)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                unlockButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
    }

    private var formColumn: some View {
        VStack(alignment: isSideBySide ? .leading : .center, spacing: 24) {
            header
            VStack(alignment: .leading, spacing: 10) {
                credentialsCard
                Button("Where do I find the password?") {
                    showPasswordHelp = true
                }
                .buttonStyle(.borderless)
                .font(.footnote)
                .padding(.horizontal, 4)
                #if os(macOS)
                .popover(isPresented: $showPasswordHelp, arrowEdge: .bottom) {
                    PasswordHelpPopover()
                }
                #else
                .unlockHelpSheet(isPresented: $showPasswordHelp, title: "Family Password") {
                    PasswordHelpPopover(showsInlineTitle: false)
                }
                #endif
            }
            frameSetup
            if let err = session.unlockError {
                Label(err, systemImage: "exclamationmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isSideBySide {
                unlockButton
            }
        }
    }

    private var header: some View {
        let alignment: TextAlignment = isSideBySide ? .leading : .center
        return VStack(alignment: isSideBySide ? .leading : .center, spacing: 8) {
            Text("Welcome to Gattey Photos")
                .font(AppTypography.primaryTitle)
                .multilineTextAlignment(alignment)
            Text("Sign in with your name and the family password.")
                .font(AppTypography.unlockSubtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: isSideBySide ? .leading : .center)
    }

    private var credentialsCard: some View {
        UnlockFieldCard {
            TextField("Your name", text: $displayName)
                .textContentType(.username)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .name)
                #if os(iOS)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                #endif
                .unlockFieldRow()
            Divider()
                .padding(.leading, unlockFieldRowInset)
            HStack(spacing: 8) {
                UnlockPasswordField(
                    text: $password,
                    showsPlaintext: showPassword,
                    placeholder: "Family password"
                )
                // The macOS AutoFill field is AppKit-backed: SwiftUI focus and submit don't reach it, and Return
                // reaches Unlock through its default-action shortcut instead.
                #if os(iOS)
                .focused($focusedField, equals: .password)
                .onSubmit { Task { await attemptUnlock() } }
                #endif
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                .help(showPassword ? "Hide password" : "Show password")
            }
            .unlockFieldRow()
        }
    }

    private var frameSetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { showsFrameSetup.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.artframe")
                    Text("Set up a frame now")
                    Text("Optional")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showsFrameSetup ? 90 : 0))
                }
                .font(.callout)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)

            if showsFrameSetup {
                UnlockFieldCard {
                    TextField(
                        "Setup block",
                        text: $bloomin8SetupText,
                        prompt: Text("Paste the Bloomin8 setup block"),
                        axis: .vertical
                    )
                    .labelsHidden()
                    .lineLimit(3...6)
                    .font(.system(.callout, design: .monospaced))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .unlockFieldRow()
                }
                Button("How do I get the setup block?") {
                    showBloomin8Help = true
                }
                .buttonStyle(.borderless)
                .font(.footnote)
                .padding(.horizontal, 4)
                #if os(macOS)
                .popover(isPresented: $showBloomin8Help, arrowEdge: .bottom) {
                    Bloomin8TokenHelpPopover()
                }
                #else
                .unlockHelpSheet(isPresented: $showBloomin8Help, title: "Add a Frame") {
                    Bloomin8TokenHelpPopover(showsInlineTitle: false)
                }
                #endif
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unlockButton: some View {
        Button {
            Task { await attemptUnlock() }
        } label: {
            ZStack {
                Text("Unlock")
                    .opacity(isUnlocking ? 0 : 1)
                if isUnlocking {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            #if os(iOS)
            .frame(minHeight: 34)
            #endif
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(isUnlocking || !canSubmitUnlock)
        .keyboardShortcut(.defaultAction)
    }

    private var canSubmitUnlock: Bool {
        let nameOK = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return nameOK && !password.isEmpty
    }

    private func attemptUnlock() async {
        guard canSubmitUnlock, !isUnlocking else { return }
        session.unlockError = nil
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        isUnlocking = true
        defer { isUnlocking = false }
        let ok = await session.unlock(password: password, store: store)
        if ok {
            password = ""
            let setupPaste = bloomin8SetupText.trimmingCharacters(in: .whitespacesAndNewlines)
            bloomin8SetupText = ""
            store.settings.displayName = trimmedName
            store.saveSettings(propagateDisplayNameChange: false)
            if !setupPaste.isEmpty {
                do {
                    try await store.registerFrame(setupText: setupPaste)
                } catch {
                    session.unlockError =
                        "Signed in, but frame registration failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// Inset grouped card holding borderless fields, like a Settings section.
private struct UnlockFieldCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(UnlockFieldCardBackground())
    }
}

private struct UnlockFieldCardBackground: View {
    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        #if os(iOS)
        shape.fill(Color(uiColor: .secondarySystemGroupedBackground))
        #else
        shape
            .fill(.background.opacity(0.7))
            .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        #endif
    }
}

extension View {
    fileprivate func unlockFieldRow() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, unlockFieldRowInset)
            .frame(minHeight: 48)
    }
}

struct PasswordHelpPopover: View {
    var showsInlineTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsInlineTitle {
                Text("Family Password")
                    .font(.headline)
            }
            (Text("Look up ") + Text("Gattey Photos Key").fontWeight(.semibold)
                + Text(" in 1Password (website URL should be ")
                + Text("https://photos.gattey.com").fontWeight(.semibold)
                + Text(
                    " for AutoFill suggestions) or use the password key in the field. It is the shared password that unlocks the gallery for everyone in the family."
                ))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 360, alignment: .leading)
        #else
        .frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }
}

struct Bloomin8TokenHelpPopover: View {
    var showsInlineTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsInlineTitle {
                Text("Add a Frame")
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 10) {
                helpStep(
                    1,
                    "Download the Bloomin8 app and set up your device."
                )
                helpStep(
                    2,
                    "Open the Devices tab and click the gear icon for settings."
                )
                helpStep(
                    3,
                    "Turn on Remote Image Push and set the interval to every 1 hour—do this while you're in device settings so photos can sync as soon as you're ready."
                )
                helpStep(
                    4,
                    "Scroll to API token. If you already created a key for this frame, open Bloomin8 on another signed-in device and copy that token’s value—you cannot generate a second key here. Otherwise tap the token row and Generate, then copy the block."
                )
                helpStep(
                    5,
                    "Paste the full setup block (device name + token) into Set up a frame on sign-in or into Settings → Frames."
                )
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 360, alignment: .leading)
        #else
        .frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }

    private func helpStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.body.weight(.semibold))
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if os(iOS)
extension View {
    func unlockHelpSheet<Content: View>(
        isPresented: Binding<Bool>,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack {
                ScrollView {
                    content()
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isPresented.wrappedValue = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
#endif
