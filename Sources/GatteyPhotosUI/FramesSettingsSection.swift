import GatteyPhotosCore
import SwiftUI

/// Family frames registered on the server (any member can add/remove). Tokens stay on the server.
struct FramesSettingsSection: View {
    @Environment(GalleryStore.self) private var store
    @State private var setupPasteText = ""
    @State private var showBloomin8Help = false
    @State private var registerError: String?
    @State private var isRegistering = false
    @State private var deletingFrameID: String?
    @State private var isAddingFrame = false
    @FocusState private var isPasteFieldFocused: Bool

    var body: some View {
        Section {
            allFramesRow
            ForEach(store.registeredFrames) { frame in
                frameRow(frame)
            }
            addFrameButton
            if isAddingFrame {
                addFrameField
            }
        } header: {
            HStack(spacing: 4) {
                Text("Frames")
                Spacer()
                Button {
                    showBloomin8Help = true
                } label: {
                    Label("How to add a frame", systemImage: "questionmark.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("How to add a Bloomin8 frame")
                #if os(macOS)
                .popover(isPresented: $showBloomin8Help, arrowEdge: .top) {
                    Bloomin8TokenHelpPopover()
                }
                #else
                .unlockHelpSheet(isPresented: $showBloomin8Help, title: "Add a Frame") {
                    Bloomin8TokenHelpPopover(showsInlineTitle: false)
                }
                #endif
            }
        } footer: {
            if let registerError {
                Text(registerError)
                    .foregroundStyle(.red)
                    .settingsFooterAlignment()
            }
        }
    }

    /// Lifecycle lives on this always-present row: modifiers on a `Form` section repeat for every row.
    private var allFramesRow: some View {
        LinkStatusRow(title: "All Frames", status: store.deviceLinkStatus)
            .task {
                await store.reloadRegisteredFrames()
                if store.registeredFrames.isEmpty {
                    isAddingFrame = true
                }
            }
            .onChange(of: store.registeredFrames.count) { _, count in
                if count == 0 {
                    isAddingFrame = true
                }
            }
            .onChange(of: isPasteFieldFocused) { wasFocused, isFocused in
                if wasFocused, !isFocused {
                    Task { await submitRegistrationIfNeeded() }
                }
            }
            .onChange(of: isAddingFrame) { _, isExpanded in
                if !isExpanded {
                    registerError = nil
                }
            }
    }

    @ViewBuilder
    private func frameRow(_ frame: RegisteredDevicePublic) -> some View {
        let isDeleting = deletingFrameID == frame.id
        HStack(spacing: 12) {
            Image(systemName: "photo.artframe")
                .font(.title3)
                .foregroundStyle(AppBrandColor.accentGreen)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(frame.displayName)
                Text(PhotoFormatters.deviceRegisteredAt(frame.registeredAt, registeredBy: frame.registeredBy))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let err = frame.lastPushError, !err.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let at = frame.lastPushAt {
                    Text(PhotoFormatters.deviceLastPushAt(at))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if isDeleting {
                ProgressView()
                    .controlSize(.small)
            } else {
                #if os(macOS)
                Button(role: .destructive) {
                    Task { await removeFrame(frame.id) }
                } label: {
                    Label("Remove", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Remove frame from server")
                #endif
            }
        }
        .opacity(isDeleting ? 0.6 : 1)
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            Button("Remove", systemImage: "trash", role: .destructive) {
                Task { await removeFrame(frame.id) }
            }
        }
        .contextMenu {
            Button("Remove Frame", systemImage: "trash", role: .destructive) {
                Task { await removeFrame(frame.id) }
            }
        }
        #endif
    }

    private var addFrameButton: some View {
        Button {
            let willExpand = !isAddingFrame
            withAnimation(.snappy(duration: 0.2)) {
                isAddingFrame = willExpand
            }
            if willExpand {
                isPasteFieldFocused = true
            }
        } label: {
            Label {
                Text("Add Frame")
            } icon: {
                Image(systemName: isAddingFrame ? "minus.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(AppBrandColor.accentGreen)
            }
        }
        #if os(macOS)
        .buttonStyle(.borderless)
        #endif
    }

    private var addFrameField: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField(
                "Setup block",
                text: $setupPasteText,
                prompt: Text("Paste the Bloomin8 setup block or API key"),
                axis: .vertical
            )
            .labelsHidden()
            .lineLimit(2...6)
            .font(.system(.footnote, design: .monospaced))
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .focused($isPasteFieldFocused)
            .disabled(isRegistering)
            .onSubmit {
                Task { await submitRegistrationIfNeeded() }
            }
            if isRegistering {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func submitRegistrationIfNeeded() async {
        guard isAddingFrame, !isRegistering else { return }
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
                isAddingFrame = false
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
