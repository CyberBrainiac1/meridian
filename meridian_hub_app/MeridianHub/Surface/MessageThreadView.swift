import SwiftUI

/// The resident<->family chat thread, opened as a `.sheet` from
/// `HubSurfaceView` — same presentation pattern as `HelpPanelView`. Everyone
/// linked to this resident (every family member, and the resident) reads and
/// writes the same single thread, so messages are labelled with who sent
/// them rather than assumed to be from one person.
///
/// Same non-negotiables as the rest of this Hub: every control clears
/// `MeridianTouchTarget.minSize`, icon + text always, nothing here silently
/// fails or silently succeeds without the resident seeing it, and closing is
/// always available as an explicit button — never only a sheet-drag gesture.
struct MessageThreadView: View {
    let profile: HubProfile

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MessageThreadViewModel

    init(profile: HubProfile) {
        self.profile = profile
        _model = StateObject(wrappedValue: MessageThreadViewModel(profile: profile))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !model.online {
                connectionBanner
            }

            if let notice = model.notice {
                HubNoticeBanner(notice: notice)
                    .padding(.horizontal, MeridianSpacing.lg)
                    .padding(.top, MeridianSpacing.sm)
            }

            messageList

            composer
        }
        .background(MeridianColor.background.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        // Announced rather than merely drawn, same as HubSurfaceView: a
        // resident using VoiceOver has to be told a send failed, not just
        // shown it.
        .onChange(of: model.notice) { _, newValue in
            guard let newValue else { return }
            AccessibilityNotification.Announcement(newValue.text).post()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: MeridianSpacing.md) {
            VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                Text("Messages")
                    .font(MeridianFont.heading())
                    .foregroundStyle(MeridianColor.foreground)
                    .accessibilityAddTraits(.isHeader)
                Text("Talk with your family here.")
                    .font(MeridianFont.body())
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MeridianSpacing.sm)

            // The sheet can still be dragged closed, but that is never the
            // only way — a resident with a tremor may not manage a drag.
            Button {
                dismiss()
            } label: {
                HStack(spacing: MeridianSpacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .font(MeridianFont.heading(24))
                        .accessibilityHidden(true)
                    Text("Close")
                        .font(MeridianFont.bodyStrong())
                }
                .padding(.horizontal, MeridianSpacing.md)
                .frame(minHeight: MeridianTouchTarget.minSize)
                .foregroundStyle(MeridianColor.primary)
                .background(MeridianColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: MeridianRadius.control)
                        .strokeBorder(MeridianColor.primary, lineWidth: 3)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close messages")
            .accessibilityHint("Goes back to the main screen")
        }
        .padding(MeridianSpacing.lg)
    }

    // MARK: Connection

    private var connectionBanner: some View {
        HStack(alignment: .top, spacing: MeridianSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(MeridianFont.heading(26))
                .accessibilityHidden(true)
            Text(HubCopy.connectionProblem)
                .font(MeridianFont.bodyStrong())
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(MeridianColor.warning)
        .padding(MeridianSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MeridianColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.control)
                .strokeBorder(MeridianColor.warning, lineWidth: 4)
        )
        .padding(.horizontal, MeridianSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection problem. \(HubCopy.connectionProblem)")
    }

    // MARK: Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: MeridianSpacing.md) {
                    if model.isLoading && model.messages.isEmpty {
                        ProgressView()
                            .tint(MeridianColor.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, MeridianSpacing.xl)
                    } else if model.messages.isEmpty {
                        Text("No messages yet. Send one below to start the conversation with your family.")
                            .font(MeridianFont.body())
                            .foregroundStyle(MeridianColor.foregroundMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, MeridianSpacing.xl)
                    } else {
                        ForEach(model.messages) { message in
                            MessageBubble(
                                message: message,
                                isMine: message.senderRole == .resident,
                                isSending: model.pendingIDs.contains(message.id)
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(MeridianSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: model.messages.count) { _, _ in
                guard let lastID = model.messages.last?.id else { return }
                withAnimation(.easeOut(duration: MeridianMotion.duration)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onAppear {
                guard let lastID = model.messages.last?.id else { return }
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: MeridianSpacing.sm) {
            TextField("Type a message", text: $model.draft, axis: .vertical)
                .font(MeridianFont.body())
                .foregroundStyle(MeridianColor.foreground)
                .lineLimit(1...4)
                .padding(MeridianSpacing.md)
                .frame(minHeight: MeridianTouchTarget.minSize)
                .background(MeridianColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: MeridianRadius.control)
                        .strokeBorder(MeridianColor.borderSoft, lineWidth: 2)
                )
                .disabled(model.isSending)
                .accessibilityLabel("Message")
                .accessibilityHint("Type a message to send to your family")

            Button {
                Task { await model.send() }
            } label: {
                HStack(spacing: MeridianSpacing.xs) {
                    if model.isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(MeridianColor.onPrimary)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(MeridianFont.bodyStrong(22))
                            .accessibilityHidden(true)
                    }
                    Text(model.isSending ? "Sending" : "Send")
                        .font(MeridianFont.bodyStrong(22))
                }
                .padding(.horizontal, MeridianSpacing.lg)
                .frame(minHeight: MeridianTouchTarget.minSize)
                .foregroundStyle(MeridianColor.onPrimary)
                .background(
                    (model.canSend && model.online) ? MeridianColor.primary : MeridianColor.primary.opacity(0.45)
                )
                .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
            }
            .buttonStyle(.plain)
            .disabled(!model.canSend || !model.online)
            .accessibilityLabel("Send message")
            .accessibilityHint(
                model.online
                    ? "Sends your message to your family"
                    : "This screen is offline, so a message cannot be sent right now"
            )
            .accessibilityValue(model.isSending ? "Sending" : "")
        }
        .padding(MeridianSpacing.lg)
        .background(MeridianColor.surface)
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool
    let isSending: Bool

    private var senderLabel: String {
        isMine ? "You" : message.senderName
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: MeridianSpacing.xl) }

            VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                // The sender name is always shown, even for the resident's
                // own messages — several family members share one thread, so
                // "who said this" can never be left implicit.
                Text(senderLabel)
                    .font(MeridianFont.bodyStrong())
                    .foregroundStyle(isMine ? MeridianColor.onPrimary : MeridianColor.foregroundMuted)

                Text(message.body)
                    .font(MeridianFont.body())
                    .foregroundStyle(isMine ? MeridianColor.onPrimary : MeridianColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: MeridianSpacing.xs) {
                    Text(MeridianFormat.clockTime(message.createdAt))
                        .font(MeridianFont.body())
                        .foregroundStyle(isMine ? MeridianColor.onPrimary.opacity(0.85) : MeridianColor.foregroundMuted)
                    if isSending {
                        Text("Sending…")
                            .font(MeridianFont.bodyStrong())
                            .foregroundStyle(isMine ? MeridianColor.onPrimary.opacity(0.85) : MeridianColor.foregroundMuted)
                    }
                }
            }
            .padding(MeridianSpacing.md)
            .frame(maxWidth: 320, alignment: .leading)
            // Alignment/side AND background distinguish sender, never colour
            // alone — the resident's own bubbles sit right and filled, a
            // family member's sit left with an outline.
            .background(isMine ? MeridianColor.primary : MeridianColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: MeridianRadius.control)
                    .strokeBorder(isMine ? Color.clear : MeridianColor.borderSoft, lineWidth: isMine ? 0 : 2)
            )

            if !isMine { Spacer(minLength: MeridianSpacing.xl) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(senderLabel) said, \(message.body), at \(MeridianFormat.clockTime(message.createdAt))"
                + (isSending ? ", sending" : "")
        )
    }
}
