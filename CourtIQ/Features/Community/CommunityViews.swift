import SwiftUI

/// Community tab — anchored entirely to today's Tip of the Day.
/// Users can read the tip and leave a comment. No general threads.
struct CommunityFeedView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var discussionStore: DiscussionStore
    @EnvironmentObject private var tipManager: TipManager
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                tipHeader
                TipCommentSectionView(
                    tipID: tipManager.todayThreadID,
                    tipTitle: tipManager.todayTip.title
                )
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("community.title"))
        .task {
            try? await discussionStore.refreshThread(threadID: tipManager.todayThreadID)
        }
    }

    /// Shows today's tip in a compact card so the discussion has context.
    private var tipHeader: some View {
        let tip = tipManager.todayTip
        return VStack(alignment: .leading, spacing: 10) {
            Label(tip.category.title, systemImage: tip.category.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.clay)

            Text(tip.title)
                .font(.title3.bold())

            Text(tip.body)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .lineLimit(4)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Comment Section

struct TipCommentSectionView: View {
    let tipID: String
    let tipTitle: String

    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var discussionStore: DiscussionStore
    @EnvironmentObject private var lang: LanguageManager

    @State private var draft = ""
    @State private var editingCommentID: String?
    @State private var showPaywall = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var reportMessage: String?
    @State private var reportingComment: DiscussionComment?

    private var comments: [DiscussionComment] {
        discussionStore.comments(for: tipID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(lang.t("community.title"))
                    .font(.title3.bold())
                Spacer()
                Text("\(comments.count) \(lang.t("community.comments"))")
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }

            commentsList
            composer
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Community")
                    .environmentObject(session)
            }
        }
        .confirmationDialog(
            lang.t("community.report_title"),
            isPresented: Binding(get: { reportingComment != nil }, set: { if !$0 { reportingComment = nil } }),
            titleVisibility: .visible
        ) {
            Button(lang.t("community.report_action"), role: .destructive) {
                guard let comment = reportingComment else { return }
                Task { await report(comment) }
            }
            Button(lang.t("common.cancel"), role: .cancel) { reportingComment = nil }
        } message: {
            Text(lang.t("community.report_guideline"))
        }
        .alert(lang.t("community.title"), isPresented: Binding(
            get: { reportMessage != nil || errorMessage != nil },
            set: { if !$0 { reportMessage = nil; errorMessage = nil } }
        )) {
            Button(lang.t("common.ok"), role: .cancel) {}
        } message: {
            Text(reportMessage ?? errorMessage ?? "")
        }
    }

    // MARK: Comments list

    private var commentsList: some View {
        Group {
            if comments.isEmpty {
                Text(lang.t("community.empty"))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(comments) { comment in
                        commentRow(comment)
                    }
                }
            }
        }
    }

    private func commentRow(_ comment: DiscussionComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.authorName)
                        .font(.subheadline.weight(.semibold))
                    Text(comment.createdAt.relativeDisplay)
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }
                Spacer()
                if comment.isPinned {
                    Text(lang.t("community.coach"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppPalette.clay.opacity(0.12))
                        .foregroundStyle(AppPalette.clay)
                        .clipShape(Capsule())
                }
            }

            Text(comment.body)
                .font(.subheadline)

            HStack(spacing: 14) {
                if session.canWriteCommunityComment {
                    Button {
                        Task { await toggleLike(comment) }
                    } label: {
                        Label("\(comment.likeCount)",
                              systemImage: comment.viewerHasLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }

                if comment.canEdit {
                    Button(lang.t("common.edit")) {
                        draft = comment.body
                        editingCommentID = comment.id
                    }
                    .buttonStyle(.plain)

                    Button(lang.t("common.delete"), role: .destructive) {
                        Task { await delete(comment) }
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                } else if session.canWriteCommunityComment {
                    Button(lang.t("common.report")) {
                        reportingComment = comment
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppPalette.clay.opacity(0.7))
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editingCommentID == nil ? lang.t("community.add_take") : lang.t("community.edit_comment"))
                .font(.headline)

            if !session.canWriteCommunityComment {
                Text(lang.t("community.unlock_desc"))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)

                Button(lang.t("community.unlock")) { showPaywall = true }
                    .buttonStyle(.borderedProminent)
            } else {
                TextField(lang.t("community.placeholder"), text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)

                HStack(spacing: 10) {
                    Button(isWorking ? lang.t("common.saving") : (editingCommentID == nil ? lang.t("common.post") : lang.t("common.save"))) {
                        Task { await submitComment() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if editingCommentID != nil {
                        Button(lang.t("common.cancel")) {
                            editingCommentID = nil
                            draft = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Actions

    private func submitComment() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            if let id = editingCommentID {
                try await discussionStore.updateComment(commentID: id, in: tipID, body: body)
                editingCommentID = nil
            } else {
                try await discussionStore.postComment(body: body, to: tipID)
            }
            draft = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleLike(_ comment: DiscussionComment) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await discussionStore.toggleLike(commentID: comment.id, in: tipID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ comment: DiscussionComment) async {
        isWorking = true
        defer { isWorking = false }
        if editingCommentID == comment.id { editingCommentID = nil; draft = "" }
        do {
            try await discussionStore.deleteComment(commentID: comment.id, in: tipID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func report(_ comment: DiscussionComment) async {
        reportingComment = nil
        do {
            try await discussionStore.report(commentID: comment.id, in: tipID, reason: "inappropriate")
            reportMessage = lang.t("community.report_thanks")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Date helper

private extension Date {
    var relativeDisplay: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: Date())
    }
}
