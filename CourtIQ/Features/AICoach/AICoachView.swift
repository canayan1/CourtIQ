import SwiftUI

/// Root of the AI Coach feature. Shows the user's saved threads + a
/// "New chat" entry that opens an empty `AICoachThreadView`. Premium
/// gating happens UPSTREAM (in `ProfileView.aiCoachSection`) — by
/// the time we render this view, we know the user is entitled.
struct AICoachView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var aiClient: AIChatClient

    @State private var openNewChat = false
    @State private var openThread: AIChatThread?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                quotaCard
                if aiClient.threads.isEmpty {
                    emptyState
                } else {
                    threadList
                }
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("ai.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openNewChat = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppPalette.clay)
                }
                .accessibilityLabel(lang.t("ai.new_chat"))
            }
        }
        .sheet(isPresented: $openNewChat) {
            NavigationStack {
                AICoachThreadView(thread: nil)
                    .environmentObject(lang)
                    .environmentObject(aiClient)
            }
        }
        .sheet(item: $openThread) { thread in
            NavigationStack {
                AICoachThreadView(thread: thread)
                    .environmentObject(lang)
                    .environmentObject(aiClient)
            }
        }
        .onAppear { aiClient.refreshQuotaForToday() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(lang.t("ai.kicker"), systemImage: "sparkles")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(lang.t("ai.headline"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quotaCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(AppPalette.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(quotaTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(lang.t("ai.quota_resets"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
        }
        .padding(14)
        .background(AppPalette.gold.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.gold.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var quotaTitle: String {
        if let remaining = aiClient.remainingToday {
            return String(format: lang.t("ai.quota_remaining_format"), remaining)
        }
        return lang.t("ai.quota_unknown")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppPalette.clay.opacity(0.4))
            Text(lang.t("ai.empty_title"))
                .font(.headline)
            Text(lang.t("ai.empty_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                openNewChat = true
            } label: {
                Text(lang.t("ai.start_first"))
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 28)
    }

    private var threadList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("ai.recent_chats"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(aiClient.threads) { thread in
                Button {
                    openThread = thread
                } label: {
                    threadRow(thread)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func threadRow(_ thread: AIChatThread) -> some View {
        let preview = thread.messages.last?.content ?? lang.t("ai.no_messages_yet")
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.bubble.fill")
                .font(.title3)
                .foregroundStyle(AppPalette.clay)
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .lineLimit(1)
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .lineLimit(2)
                Text(relativeDate(thread.lastMessageAt))
                    .font(.caption2)
                    .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func relativeDate(_ d: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: d, relativeTo: Date())
    }
}
