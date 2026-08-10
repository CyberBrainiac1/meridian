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
                        .foregroundStyle(FamColor.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, FamSpacing.md)
                        .padding(.top, FamSpacing.xs)
                }

                composer
            }
            .background(FamColor.background)
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
        .padding(.horizontal, FamSpacing.md)
        .padding(.top, FamSpacing.sm)
    }

    @ViewBuilder
    private var threadContent: some View {
        if let resident = viewModel.selectedResident {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: FamSpacing.sm) {
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
                                .foregroundStyle(FamColor.warning)
                        }
                    }
                    .padding(FamSpacing.md)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    guard let lastId = viewModel.messages.last?.id else { return }
                    withAnimation(.easeInOut(duration: FamMotion.duration)) {
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
        VStack(spacing: FamSpacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 32))
                .foregroundStyle(FamColor.success)
            Text("Send the first message to \(resident.displayName)")
                .font(FamFont.heading(18))
                .foregroundStyle(FamColor.foreground)
                .multilineTextAlignment(.center)
            Text("Messages here go to \(resident.displayName) and everyone else in the family linked to them.")
                .font(FamFont.body(15))
                .foregroundStyle(FamColor.foregroundMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FamSpacing.xl)
        .padding(.horizontal, FamSpacing.lg)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: FamSpacing.sm) {
            TextField("Message", text: $viewModel.draftText, axis: .vertical)
                .font(FamFont.body(16))
                .foregroundStyle(FamColor.foreground)
                .tint(FamColor.primaryAlt)
                .lineLimit(1...4)
                .focused($isComposerFocused)
                .disabled(viewModel.selectedResident == nil)
                .padding(.horizontal, FamSpacing.sm)
                .frame(minHeight: FamTouchTarget.minSize)
                .background(FamColor.surface, in: RoundedRectangle(cornerRadius: FamRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: FamRadius.control)
                        .stroke(FamColor.border, lineWidth: 1)
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
            .buttonStyle(FamButtonStyle(kind: .success))
            .disabled(
                viewModel.isSending
                    || viewModel.selectedResident == nil
                    || viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .accessibilityLabel("Send message")
        }
        .padding(FamSpacing.md)
        .background(FamColor.surface)
    }
}

private struct MessageBubble: View {
    let message: Message
    let isOwnMessage: Bool

    var body: some View {
        VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 2) {
            Text(senderLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FamColor.foregroundMuted)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.body)
                    .font(FamFont.body(16))
                    .foregroundStyle(bodyForeground)
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(bodyForeground.opacity(0.7))
            }
            .padding(FamSpacing.sm)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: FamRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: FamRadius.control)
                    .stroke(isOwnMessage ? .clear : FamColor.border, lineWidth: 1)
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
        if isOwnMessage { return FamColor.successStrong }
        if message.senderRole == .resident { return FamColor.surface }
        return FamColor.muted
    }

    private var bodyForeground: Color {
        isOwnMessage ? .white : FamColor.foreground
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
        VStack(spacing: FamSpacing.lg) {
            VStack(spacing: FamSpacing.unit) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 36))
                    .foregroundStyle(FamColor.success)
                Text("What's your name?")
                    .font(FamFont.heading(20))
                    .foregroundStyle(FamColor.foreground)
                Text("This is shown on every message you send, so your family knows it's you.")
                    .font(FamFont.body(15))
                    .foregroundStyle(FamColor.foregroundMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, FamSpacing.xl)

            TextField("Your name", text: $name)
                .foregroundStyle(FamColor.foreground)
                .tint(FamColor.primaryAlt)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(onConfirm)
                .padding()
                .frame(minHeight: FamTouchTarget.minSize)
                .background(FamColor.background, in: RoundedRectangle(cornerRadius: FamRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: FamRadius.control)
                        .stroke(FamColor.border, lineWidth: 1)
                )
                .accessibilityLabel("Your name")

            Button {
                onConfirm()
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(FamButtonStyle(kind: .success))
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Not now", action: onCancel)
                .font(FamFont.body(15))
                .foregroundStyle(FamColor.foregroundMuted)
                .frame(minHeight: FamTouchTarget.minSize)

            Spacer()
        }
        .padding(FamSpacing.lg)
        .background(FamColor.background)
        .onAppear { isFocused = true }
    }
}
