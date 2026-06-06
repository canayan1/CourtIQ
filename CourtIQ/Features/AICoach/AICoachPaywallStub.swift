import SwiftUI

/// Mini paywall shown when a non-premium user taps the AI Coach card.
/// AI Coach is the ONE genuinely-paid feature in CourtIQ (every other
/// surface is free), so the copy needs to set that expectation cleanly
/// without sounding like a generic "subscribe" wall.
struct AICoachPaywallStub: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    bullets
                    cta
                    legalNote
                }
                .padding(22)
                .padding(.top, 6)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("ai.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("common.done")) { dismiss() }
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(AppPalette.clay)
                .padding(20)
                .background(AppPalette.clay.opacity(0.12))
                .clipShape(Circle())

            Text(lang.t("ai.paywall_headline"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppPalette.ink)

            Text(lang.t("ai.paywall_subhead"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(.top, 12)
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet(icon: "person.crop.circle.fill", text: lang.t("ai.paywall_bullet_context"))
            bullet(icon: "list.bullet.rectangle.fill", text: lang.t("ai.paywall_bullet_library"))
            bullet(icon: "doc.append.fill", text: lang.t("ai.paywall_bullet_import"))
            bullet(icon: "lock.shield.fill", text: lang.t("ai.paywall_bullet_privacy"))
        }
        .padding(18)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.clay)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @State private var openSupporterSheet = false

    private var cta: some View {
        VStack(spacing: 10) {
            Button {
                openSupporterSheet = true
            } label: {
                Label(lang.t("ai.paywall_cta"), systemImage: "heart.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)

            Text(lang.t("ai.paywall_price_hint"))
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .sheet(isPresented: $openSupporterSheet) {
            NavigationStack {
                PaywallView(source: "AICoach")
                    .environmentObject(session)
            }
        }
    }

    private var legalNote: some View {
        Text(lang.t("ai.paywall_legal"))
            .font(.caption2)
            .foregroundStyle(AppPalette.inkSoft)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
    }
}
