import SwiftUI

/// The resident<->family chat thread, opened as a `.sheet` from
/// `HubSurfaceView` — same presentation pattern as `HelpPanelView`. Everyone
/// linked to this resident (every family member, and the resident) reads and
/// writes the same single thread, so messages are labelled with who sent
/// them rather than assumed to be from one person.
///
/// Same non-negotiables as the rest of this Hub: every control clears
/// `HubTouchTarget.minSize`, icon + text always, nothing here silently
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
                    .padding(.horizontal, HubSpacing.lg)
                    .padding(.top, HubSpacing.sm)
            }

            messageList

            composer
        }
        .background(HubColor.background.ignoresSafeArea())
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
        HStack(alignment: .top, spacing: HubSpacing.md) {
            VStack(alignment: .leading, spacing: HubSpacing.xs) {
                Text("Messages")
                    .font(HubFont.heading())
                    .foregroundStyle(HubColor.foreground)
                    .accessibilityAddTraits(.isHeader)
                Text("Talk with your family here.")
                    .font(HubFont.body())
                    .foregroundStyle(HubColor.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: HubSpacing.sm)

            // The sheet can still be dragged closed, but that is never the
            // only way — a resident with a tremor may not manage a drag.
            Button {
                dismiss()
            } label: {
                HStack(spacing: HubSpacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HubFont.heading(24))
                        .accessibilityHidden(true)
                    Text("Close")
                        .font(HubFont.bodyStrong())
                }
                .padding(.horizontal, HubSpacing.md)
                .frame(minHeight: HubTouchTarget.minSize)
                .foregroundStyle(HubColor.primary)
                .background(HubColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: HubRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: HubRadius.control)
                        .strokeBorder(HubColor.primary, lineWidth: 3)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close messages")
            .accessibilityHint("Goes back to the main screen")
        }
        .padding(HubSpacing.lg)
    }

    // MARK: Connection

    private var connectionBanner: some View {
        HStack(alignment: .top, spacing: HubSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(HubFont.heading(26))
                .accessibilityHidden(true)
            Text(HubCopy.connectionProblem)
                .font(HubFont.bodyStrong())
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(HubColor.warning)
        .padding(HubSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HubColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: HubRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: HubRadius.control)
                .strokeBorder(HubColor.warning, lineWidth: 4)
        )
        .padding(.horizontal, HubSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection problem. \(HubCopy.connectionProblem)")
    }

    // MARK: Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: HubSpacing.md) {
                    if model.isLoading && model.messages.isEmpty {
                        ProgressView()
                            .tint(HubColor.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, HubSpacing.xl)
                    } else if model.messages.isEmpty {
                        Text("No messages yet. Send one below to start the conversation with your family.")
                            .font(HubFont.body())
                            .foregroundStyle(HubColor.foregroundMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, HubSpacing.xl)
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
                .padding(HubSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: model.messages.count) { _, _ in
                guard let lastID = model.messages.last?.id else { return }
                withAnimation(.easeOut(duration: HubMotion.duration)) {
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
        HStack(alignment: .bottom, spacing: HubSpacing.sm) {
            TextField("Type a message", text: $model.draft, axis: .vertical)
                .font(HubFont.body())
                .foregroundStyle(HubColor.foreground)
                .lineLimit(1...4)
                .padding(HubSpacing.md)
                .frame(minHeight: HubTouchTarget.minSize)
                .background(HubColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: HubRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: HubRadius.control)
                        .strokeBorder(HubColor.borderSoft, lineWidth: 2)
                )
                .disabled(model.isSending)
                .accessibilityLabel("Message")
                .accessibilityHint("Type a message to send to your family")

            Button {
                Task { await model.send() }
            } label: {
                HStack(spacing: HubSpacing.xs) {
                    if model.isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(HubColor.onPrimary)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(HubFont.bodyStrong(22))
                            .accessibilityHidden(true)
                    }
                    Text(model.isSending ? "Sending" : "Send")
                        .font(HubFont.bodyStrong(22))
                }
                .padding(.horizontal, HubSpacing.lg)
                .frame(minHeight: HubTouchTarget.minSize)
                .foregroundStyle(HubColor.onPrimary)
                .background(
                    (model.canSend && model.online) ? HubColor.primary : HubColor.primary.opacity(0.45)
                )
                .clipShape(RoundedRectangle(cornerRadius: HubRadius.control))
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
        .padding(HubSpacing.lg)
        .background(HubColor.surface)
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
            if isMine { Spacer(minLength: HubSpacing.xl) }

            VStack(alignment: .leading, spacing: HubSpacing.xs) {
                // The sender name is always shown, even for the resident's
                // own messages — several family members share one thread, so
                // "who said this" can never be left implicit.
                Text(senderLabel)
                    .font(HubFont.bodyStrong())
                    .foregroundStyle(isMine ? HubColor.onPrimary : HubColor.foregroundMuted)

                Text(message.body)
                    .font(HubFont.body())
                    .foregroundStyle(isMine ? HubColor.onPrimary : HubColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: HubSpacing.xs) {
                    Text(HubFormat.clockTime(message.createdAt))
                        .font(HubFont.body())
                        .foregroundStyle(isMine ? HubColor.onPrimary.opacity(0.85) : HubColor.foregroundMuted)
                    if isSending {
                        Text("Sending…")
                            .font(HubFont.bodyStrong())
                            .foregroundStyle(isMine ? HubColor.onPrimary.opacity(0.85) : HubColor.foregroundMuted)
                    }
                }
            }
            .padding(HubSpacing.md)
            .frame(maxWidth: 320, alignment: .leading)
            // Alignment/side AND background distinguish sender, never colour
            // alone — the resident's own bubbles sit right and filled, a
            // family member's sit left with an outline.
            .background(isMine ? HubColor.primary : HubColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: HubRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: HubRadius.control)
                    .strokeBorder(isMine ? Color.clear : HubColor.borderSoft, lineWidth: isMine ? 0 : 2)
            )

            if !isMine { Spacer(minLength: HubSpacing.xl) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(senderLabel) said, \(message.body), at \(HubFormat.clockTime(message.createdAt))"
                + (isSending ? ", sending" : "")
        )
    }
}
