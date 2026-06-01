import GatteyPhotosCore
import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var store: GalleryStore
    @EnvironmentObject private var session: AppSession
    @State private var displayName = AppSettings.defaultDisplayName
    @State private var password = ""
    @State private var bloomin8SetupText = ""
    @State private var showPassword = false
    @State private var showBloomin8Help = false
    @State private var showPasswordHelp = false
    @State private var isUnlocking = false
    @State private var unlockFormHeight: CGFloat = 0

    private let formWidth: CGFloat = 520
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        unlockScrollContent
        .onPreferenceChange(UnlockFormHeightPreferenceKey.self) { height in
            if height > 0, height != unlockFormHeight {
                unlockFormHeight = height
            }
        }
        #if os(iOS)
        .padding(.horizontal, unlockOuterPadding)
        #else
        .padding(unlockOuterPadding)
        #endif
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
            #if os(macOS)
            if bloomin8SetupText.isEmpty, !store.settings.bloomin8ApiToken.isEmpty {
                bloomin8SetupText = store.settings.bloomin8ApiToken
            }
            #endif
        }
    }

    @ViewBuilder
    private var unlockScrollContent: some View {
        #if os(iOS)
        GeometryReader { geo in
            let scrollBottomInset = geo.safeAreaInsets.bottom
            ScrollView {
                unlockBody
                    .frame(maxWidth: unlockContentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .frame(
                        minHeight: horizontalSizeClass == .regular ? geo.size.height : nil,
                        alignment: .center
                    )
                    .padding(.top, horizontalSizeClass == .regular ? 40 : 16)
                    .padding(.bottom, (horizontalSizeClass == .regular ? 40 : 16) + scrollBottomInset)
            }
            .ignoresSafeArea(edges: [.top, .bottom])
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        #else
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .center, spacing: 48) {
                    UnlockWelcomePhotoPanel(contentHeight: unlockFormHeight)
                        .layoutPriority(-1)
                    unlockFormColumn
                        .background(formHeightReader)
                }
            } else {
                ScrollView {
                    unlockBody
                        .padding(.vertical, 24)
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private var unlockBody: some View {
        if horizontalSizeClass == .regular {
            HStack(alignment: .center, spacing: 48) {
                UnlockWelcomePhotoPanel(contentHeight: unlockFormHeight)
                    .layoutPriority(-1)
                unlockFormColumn
                    .background(formHeightReader)
            }
        } else {
            VStack(spacing: 20) {
                UnlockWelcomePhotoPanel(contentHeight: welcomePhotoContentHeight)
                unlockFormColumn
                    .background(formHeightReader)
            }
        }
    }

    private var welcomePhotoContentHeight: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .compact ? 0 : unlockFormHeight
        #else
        unlockFormHeight
        #endif
    }

    private var unlockOuterPadding: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .regular ? 40 : IOSContentWidth.unlockCompactHorizontalPadding
        #else
        horizontalSizeClass == .regular ? 56 : 20
        #endif
    }

    private var unlockContentMaxWidth: CGFloat? {
        #if os(iOS)
        horizontalSizeClass == .regular ? IOSContentWidth.unlockRegularMax : nil
        #else
        nil
        #endif
    }

    private var formHeightReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: UnlockFormHeightPreferenceKey.self,
                value: proxy.size.height
            )
        }
    }

    private var unlockFormColumn: some View {
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to Gattey Photos")
                        .font(AppTypography.primaryTitle)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(unlockSubtitle)
                        .font(AppTypography.unlockSubtitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your name")
                            .font(AppTypography.unlockBody)
                        TextField("Name shown on uploads", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .font(AppTypography.unlockBody)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    #if os(macOS)
                    bloomin8TokenField
                    #endif

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Family password")
                                .font(AppTypography.unlockBody)
                            Button {
                                showPasswordHelp = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.borderless)
                            #if os(macOS)
                            .help("Where to find the family password")
                            .popover(isPresented: $showPasswordHelp, arrowEdge: .top) {
                                PasswordHelpPopover()
                            }
                            #else
                            .unlockHelpSheet(isPresented: $showPasswordHelp, title: "Family password") {
                                PasswordHelpPopover(showsInlineTitle: false)
                            }
                            #endif
                            Spacer(minLength: 0)
                        }
                        HStack(spacing: 8) {
                            UnlockPasswordField(
                                text: $password,
                                showsPlaintext: showPassword,
                                placeholder: "Password"
                            )
                            .font(AppTypography.unlockBody)
                            #if os(macOS)
                            .fixedSize(horizontal: false, vertical: true)
                            #else
                            .frame(minHeight: 28)
                            #endif
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .help(showPassword ? "Hide password" : "Show password")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let err = session.unlockError {
                        Text(err)
                            .font(AppTypography.unlockBody)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        Task { await attemptUnlock() }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Unlock")
                            if isUnlocking {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(minHeight: 28)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .disabled(isUnlocking || !canSubmitUnlock)
                    .keyboardShortcut(.defaultAction)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(
            maxWidth: unlockFormColumnMaxWidth,
            alignment: .leading
        )
    }

    private var unlockFormColumnMaxWidth: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .regular ? formWidth : .infinity
        #else
        formWidth
        #endif
    }

    private var unlockSubtitle: String {
        #if os(iOS)
        "Enter your name and the family password to open the gallery."
        #else
        "Enter your name, the family password, and your device API token to open the gallery."
        #endif
    }

    private var canSubmitUnlock: Bool {
        let nameOK = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard nameOK, !password.isEmpty else { return false }
        #if os(macOS)
        return !bloomin8SetupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #else
        return true
        #endif
    }

    #if os(macOS)
    private var bloomin8TokenField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Your device API token")
                    .font(AppTypography.unlockBody)
                Button {
                    showBloomin8Help = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("How to get your API token")
                .popover(isPresented: $showBloomin8Help, arrowEdge: .top) {
                    Bloomin8TokenHelpPopover()
                }
                Spacer(minLength: 0)
            }
            TextField(
                "Paste the full block from the Bloomin8 app",
                text: $bloomin8SetupText,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .font(AppTypography.unlockBody)
            .lineLimit(3...8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    #endif

    private func attemptUnlock() async {
        session.unlockError = nil
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            session.unlockError = "Enter your name so uploads can be attributed to you."
            return
        }
        store.settings.displayName = trimmedName
        #if os(macOS)
        store.settings.bloomin8ApiToken = bloomin8SetupText
        store.applyBloomin8TokenFromPaste()
        guard !store.settings.bloomin8ApiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            session.unlockError = "Paste your device API token (full block from the device app)."
            return
        }
        #endif
        isUnlocking = true
        defer { isUnlocking = false }
        let ok = await session.unlock(password: password, store: store)
        if ok {
            password = ""
            #if os(macOS)
            bloomin8SetupText = store.settings.bloomin8ApiToken
            #endif
            store.saveSettings()
            async let status: Void = store.updateConnectionStatus()
            async let gallery: Void = store.refresh()
            _ = await (status, gallery)
        }
    }
}

private struct UnlockFormHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PasswordHelpPopover: View {
    var showsInlineTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsInlineTitle {
                Text("Family password")
                    .font(.headline)
            }
            (Text("Look up ") + Text("Gattey Photos Key").fontWeight(.semibold) + Text(" in 1Password (website URL should be ") + Text("https://photos.gattey.com").fontWeight(.semibold) + Text(" for AutoFill suggestions) or use the password key in the field. It is the shared password that unlocks the gallery for everyone in the family."))
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
                Text("Device setup")
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
                    "Scroll to API token, click it, then click Generate in the window that opens."
                )
                helpStep(
                    5,
                    "Paste the text copied to your clipboard into this API token field."
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
private extension View {
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
        }
    }
}
#endif
