import SwiftUI

struct DelightHeroOfferTemplate: View {
    let decision: DelightDecisionResponse
    let theme: DelightPopupTheme
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.22), Color.gray.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "person.crop.rectangle")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
                .frame(height: 200)

                VStack(spacing: 14) {
                    hostLogoImage()
                        .padding(.top, 12)

                    if let subtitle = decision.content.subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.7))
                    }

                    Text(decision.content.title)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.black)
                        .scaleEffect(theme.fontScale)

                    Text("As a thank you for travelling with us, we partnered with top brands to bring you a free trial offer. Cancel anytime. See terms below.")
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.black.opacity(0.55))
                        .padding(.horizontal, 20)

                    placeholderSlot(label: "Reward logo placeholder", height: 34)
                        .padding(.horizontal, 20)

                    HStack(spacing: 6) {
                        Text("Terms & Conditions")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.75))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.65))
                    }

                    placeholderSlot(label: "Small CTA text placeholder", height: 24)
                        .padding(.horizontal, 20)

                    Button(decision.content.primaryCta ?? "Claim now") {
                        onPrimary()
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.primary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 22)

                    HStack(spacing: 8) {
                        Button("Powered by RewardsBag") {}
                        Text("|")
                        Button("Privacy Policy") {}
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                }
                .background(Color.white)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            Button {
                onDismiss()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .padding(16)
        .presentationDetents([.large])
    }

    private func hostLogoImage() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(width: 168, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )

            HStack(spacing: 6) {
                Image(systemName: "circlebadge.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.blue)
                Text("Stagecoach")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
            }
        }
    }

    private func placeholderSlot(label: String, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.06))
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.gray.opacity(0.4))
                )

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.gray)
        }
    }
}
