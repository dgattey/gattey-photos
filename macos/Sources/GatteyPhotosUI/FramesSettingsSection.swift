import GatteyPhotosCore
import SwiftUI

/// Family frames registered on the server (any member can add/remove). Tokens stay on the server.
struct FramesSettingsSection: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var setupPasteText = ""
    @State private var showBloomin8Help = false
    @State private var registerError: String?
    @State private var isRegistering = false
    @State private var deletingFrameID: String?
    @State private var isAddingDeviceExpanded = false
    @FocusState private var isPasteFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Devices")
                    .font(.headline)
                Button {
                    showBloomin8Help = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("How to register a Bloomin8 frame")
                .popover(isPresented: $showBloomin8Help, arrowEdge: .top) {
                    Bloomin8TokenHelpPopover()
                }
            }

            framesStatusGroup
        }
        .onAppear {
            isAddingDeviceExpanded = store.registeredFrames.isEmpty
            Task { await store.reloadRegisteredFrames() }
        }
        .onChange(of: store.registeredFrames.count) { _, count in
            if count == 0 {
                isAddingDeviceExpanded = true
            }
        }
        .onChange(of: isPasteFieldFocused) { wasFocused, isFocused in
            if wasFocused, !isFocused {
                Task { await submitRegistrationIfNeeded() }
            }
        }
        .onChange(of: isAddingDeviceExpanded) { _, isExpanded in
            if !isExpanded {
                registerError = nil
            }
        }
    }

    private static let deviceRowInset: CGFloat = 8
    private static let deviceRowVerticalPadding: CGFloat = 14
    private static let addDeviceRowVerticalPadding: CGFloat = 10
    private static let rowCornerRadius: CGFloat = 12
    /// Tucks inset device rows under the pill’s rounded bottom edge.
    private static let deviceRowOverlap: CGFloat = 6

    @ViewBuilder
    private var framesStatusGroup: some View {
        let frames = store.registeredFrames
        VStack(spacing: 0) {
            ConnectionPill(
                title: "All frames",
                status: store.deviceLinkStatus
            )
            .zIndex(1)

            VStack(spacing: 0) {
                ForEach(frames) { frame in
                    frameRow(frame)
                }

                addDeviceRow(isLast: !isAddingDeviceExpanded)

                if isAddingDeviceExpanded {
                    addDeviceExpandedContent
                }
            }
            .padding(.top, -Self.deviceRowOverlap)
        }
    }

    @ViewBuilder
    private func frameRow(_ frame: RegisteredDevicePublic) -> some View {
        let isDeleting = deletingFrameID == frame.id
        attachedRow(
            isLast: false,
            showsBottomSeparator: true,
            verticalPadding: Self.deviceRowVerticalPadding
        ) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(frame.displayName)
                        .font(.subheadline.weight(.medium))
                    Text(PhotoFormatters.deviceRegisteredAt(frame.registeredAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let err = frame.lastPushError, !err.isEmpty {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if let at = frame.lastPushAt {
                        Text(PhotoFormatters.deviceLastPushAt(at))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                Spacer(minLength: 4)
                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minHeight: 22)
                } else {
                    Button(role: .destructive) {
                        Task { await removeFrame(frame.id) }
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove frame from server")
                }
            }
            .opacity(isDeleting ? 0.6 : 1)
        }
    }

    private func addDeviceRow(isLast: Bool) -> some View {
        attachedRow(isLast: isLast) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isAddingDeviceExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(AppBrandColor.accentGreen)
                    Text("Add a device")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isAddingDeviceExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var addDeviceExpandedContent: some View {
        attachedRow(isLast: true) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    "Paste Bloomin8 setup block or API key",
                    text: $setupPasteText,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                #if os(macOS)
                .font(.system(.caption, design: .monospaced))
                #endif
                .focused($isPasteFieldFocused)
                .disabled(isRegistering)
                .onSubmit {
                    Task { await submitRegistrationIfNeeded() }
                }

                if isRegistering {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                }

                if let registerError {
                    Text(registerError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            isPasteFieldFocused = true
        }
    }

    private func attachedRow<Content: View>(
        isLast: Bool,
        showsBottomSeparator: Bool = false,
        verticalPadding: CGFloat = Self.addDeviceRowVerticalPadding,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(settingsRowFill, in: deviceRowShape(isLast: isLast))
            .overlay(alignment: .bottom) {
                if showsBottomSeparator {
                    Rectangle()
                        .fill(deviceRowSeparatorColor)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.horizontal, Self.deviceRowInset)
    }

    private var deviceRowSeparatorColor: Color {
        switch colorScheme {
        case .light:
            return Color(red: 0.78, green: 0.78, blue: 0.80)
        case .dark:
            return Color(red: 0.34, green: 0.34, blue: 0.36)
        @unknown default:
            return Color(red: 0.34, green: 0.34, blue: 0.36)
        }
    }

    private func deviceRowShape(isLast: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: isLast ? Self.rowCornerRadius : 0,
            bottomTrailingRadius: isLast ? Self.rowCornerRadius : 0,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    private var settingsRowFill: Color {
        switch colorScheme {
        case .light:
            return Color(red: 0.94, green: 0.94, blue: 0.95)
        case .dark:
            return Color(red: 0.22, green: 0.22, blue: 0.24)
        @unknown default:
            return Color(red: 0.22, green: 0.22, blue: 0.24)
        }
    }

    private func submitRegistrationIfNeeded() async {
        guard isAddingDeviceExpanded, !isRegistering else { return }
        registerError = nil
        let paste = setupPasteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !paste.isEmpty else { return }

        guard Bloomin8TokenParser.parseToken(from: paste) != nil else {
            registerError = "Could not find a Bloomin8 API token. Paste the setup block or token only."
            return
        }

        isRegistering = true
        defer { isRegistering = false }
        do {
            try await store.registerFrame(setupText: paste)
            setupPasteText = ""
            registerError = nil
            withAnimation(.snappy(duration: 0.2)) {
                isAddingDeviceExpanded = false
            }
        } catch {
            registerError = error.localizedDescription
        }
    }

    private func removeFrame(_ id: String) async {
        guard deletingFrameID == nil else { return }
        deletingFrameID = id
        defer { deletingFrameID = nil }
        do {
            try await store.unregisterFrame(id: id)
            registerError = nil
        } catch {
            registerError = error.localizedDescription
        }
    }
}
