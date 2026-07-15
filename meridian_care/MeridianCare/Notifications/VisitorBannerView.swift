import SwiftUI

struct VisitorBannerView: View {
    @ObservedObject var viewModel: VisitorBannerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if viewModel.isVisible, let notification = viewModel.latest {
            HStack(spacing: MeridianSpacing.sm) {
                Image(systemName: "door.left.hand.open")
                    .foregroundStyle(MeridianColor.primary)
                Text(notification.body)
                    .font(MeridianFont.bodyMedium(15))
                    .foregroundStyle(MeridianColor.foreground)
                Spacer()
                Button {
                    viewModel.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(MeridianColor.foreground.opacity(0.5))
                }
                .frame(minWidth: MeridianTouchTarget.minSize, minHeight: MeridianTouchTarget.minSize)
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, MeridianSpacing.md)
            .padding(.vertical, MeridianSpacing.xs)
            .background(MeridianColor.primary.opacity(0.08))
            .overlay(Rectangle().frame(height: 1).foregroundStyle(MeridianColor.border), alignment: .bottom)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}
