import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel: MessagesViewModel
    @FocusState private var isComposerFocused: Bool

    init(residents: [FamilyLinkedResident]) {
        _viewModel = StateObject(wrappedValue: MessagesViewModel(residents: residents))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.residents.count > 1 {
                    residentPicker
                }

                threadContent

                if let sendErrorMessage = viewModel.sendErrorMessage {
                    Text(sendErrorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MeridianColor.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MeridianSpacing.md)
                        .padding(.top, MeridianSpacing.xs)
                }

                composer
            }
            .background(MeridianColor.background)
            .navigationTitle("Messages")
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .sheet(isPresented: $viewModel.isPromptingForName) {
            NameCaptureView(
                name: $viewModel.pendingName,
                onConfirm: { viewModel.confirmPendingName() },
                onCancel: { viewModel.cancelNamePrompt() }
            )
            .interactiveDismissDisabled()
        }
    }

    private var residentPicker: some View {
        Picker("Resident", selection: Binding(
            get: { viewModel.selectedResidentId },
            set: { viewModel.selectResident($0) }
        )) {
            ForEach(viewModel.residents) { resident in
                Text(resident.displayName).tag(resident.residentId)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, MeridianSpacing.md)
        .padding(.top, MeridianSpacing.sm)
    }

    @ViewBuilder
    private var threadContent: some View {
        if let resident = viewModel.selectedResident {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                        if viewModel.messages.isEmpty {
                            emptyState(for: resident)
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, isOwnMessage: viewModel.isOwnMessage(message))
                                    .id(message.id)
                            }
                        }

                        if let loadErrorMessage = viewModel.loadErrorMessage {
                            Text(loadErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(MeridianColor.warning)
                        }
                    }
                    .padding(MeridianSpacing.md)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    guard let lastId = viewModel.messages.last?.id else { return }
                    withAnimation(.easeInOut(duration: MeridianMotion.duration)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No linked resident",
                systemImage: "message",
                description: Text("You're not linked to a resident yet.")
            )
        }
    }

    private func emptyState(for resident: FamilyLinkedResident) -> some View {
        VStack(spacing: MeridianSpacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 32))
                .foregroundStyle(MeridianColor.success)
            Text("Send the first message to \(resident.displayName)")
                .font(MeridianFont.heading(18))
                .foregroundStyle(MeridianColor.foreground)
                .multilineTextAlignment(.center)
            Text("Messages here go to \(resident.displayName) and everyone else in the family linked to them.")
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foregroundMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MeridianSpacing.xl)
        .padding(.horizontal, MeridianSpacing.lg)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: MeridianSpacing.sm) {
            TextField("Message", text: $viewModel.draftText, axis: .vertical)
                .font(MeridianFont.body(16))
                .foregroundStyle(MeridianColor.foreground)
                .tint(MeridianColor.primaryAlt)
                .lineLimit(1...4)
                .focused($isComposerFocused)
                .disabled(viewModel.selectedResident == nil)
                .padding(.horizontal, MeridianSpacing.sm)
                .frame(minHeight: MeridianTouchTarget.minSize)
                .background(MeridianColor.surface, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: MeridianRadius.control)
                        .stroke(MeridianColor.border, lineWidth: 1)
                )
                .accessibilityLabel("Message")

            Button {
                isComposerFocused = false
                Task { await viewModel.send() }
            } label: {
                if viewModel.isSending {
                    ProgressView().tint(.white)
                } else {
                    Text("Send")
                }
            }
            .buttonStyle(MeridianButtonStyle(kind: .success))
            .disabled(
                viewModel.isSending
                    || viewModel.selectedResident == nil
                    || viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .accessibilityLabel("Send message")
        }
        .padding(MeridianSpacing.md)
        .background(MeridianColor.surface)
    }
}

private struct MessageBubble: View {
    let message: Message
    let isOwnMessage: Bool

    var body: some View {
        VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 2) {
            Text(senderLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MeridianColor.foregroundMuted)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.body)
                    .font(MeridianFont.body(16))
                    .foregroundStyle(bodyForeground)
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(bodyForeground.opacity(0.7))
            }
            .padding(MeridianSpacing.sm)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: MeridianRadius.control)
                    .stroke(isOwnMessage ? .clear : MeridianColor.border, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: isOwnMessage ? .trailing : .leading)
    }

    /// Multiple relatives can share this thread, so the name has to be
    /// explicit text on every bubble — side/color alone can't tell two
    /// other family members' messages apart.
    private var senderLabel: String {
        isOwnMessage ? "\(message.senderName) (You)" : message.senderName
    }

    private var bubbleBackground: Color {
        if isOwnMessage { return MeridianColor.successStrong }
        if message.senderRole == .resident { return MeridianColor.surface }
        return MeridianColor.muted
    }

    private var bodyForeground: Color {
        isOwnMessage ? .white : MeridianColor.foreground
    }
}

private struct NameCaptureView: View {
    @Binding var name: String
    let onConfirm: () -> Void
    /// An explicit way out. This sheet sets `.interactiveDismissDisabled()`,
    /// so without a cancel it is a dead end if the name can't be confirmed.
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: MeridianSpacing.lg) {
            VStack(spacing: MeridianSpacing.unit) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 36))
                    .foregroundStyle(MeridianColor.success)
                Text("What's your name?")
                    .font(MeridianFont.heading(20))
                    .foregroundStyle(MeridianColor.foreground)
                Text("This is shown on every message you send, so your family knows it's you.")
                    .font(MeridianFont.body(15))
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, MeridianSpacing.xl)

            TextField("Your name", text: $name)
                .foregroundStyle(MeridianColor.foreground)
                .tint(MeridianColor.primaryAlt)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(onConfirm)
                .padding()
                .frame(minHeight: MeridianTouchTarget.minSize)
                .background(MeridianColor.background, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: MeridianRadius.control)
                        .stroke(MeridianColor.border, lineWidth: 1)
                )
                .accessibilityLabel("Your name")

            Button {
                onConfirm()
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(MeridianButtonStyle(kind: .success))
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Not now", action: onCancel)
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foregroundMuted)
                .frame(minHeight: MeridianTouchTarget.minSize)

            Spacer()
        }
        .padding(MeridianSpacing.lg)
        .background(MeridianColor.background)
        .onAppear { isFocused = true }
    }
}
