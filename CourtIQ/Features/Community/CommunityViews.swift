import SwiftUI

struct CommunityFeedView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var discussionStore: DiscussionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard

                ForEach(discussionStore.featuredThreads) { thread in
                    NavigationLink {
                        DiscussionThreadView(threadID: thread.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(thread.title)
                                .font(.headline)
                            Text(thread.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.inkSoft)

                            HStack(spacing: 12) {
                                labelPill(systemImage: "bubble.left.and.bubble.right", text: "\(discussionStore.commentCount(for: thread.id)) comments")
                                labelPill(systemImage: "clock", text: thread.lastActivityLabel)
                            }
                        }
                        .padding()
                        .background(AppPalette.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle("Community")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep the conversation tied to the work.")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Threads stay anchored to quizzes, training sessions, and mobility flows so discussion feels useful instead of noisy.")
                .foregroundStyle(AppPalette.inkSoft)

            if !session.canWriteCommunityComment {
                Text("Reading is open in free preview. Commenting unlocks with All Access and Sign in with Apple.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.clay)
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func labelPill(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppPalette.sand.opacity(0.45))
            .clipShape(Capsule())
    }
}

struct DiscussionThreadView: View {
    let threadID: String

    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var discussionStore: DiscussionStore
    @State private var draft = ""
    @State private var editingCommentID: String?
    @State private var reportMessage: String?
    @State private var showPaywall = false

    private var thread: DiscussionThread? {
        discussionStore.thread(withID: threadID)
    }

    private var comments: [DiscussionComment] {
        discussionStore.comments(for: threadID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let thread {
                    header(thread)
                    pinnedPrompt(thread)
                    commentsList
                    composer
                } else {
                    Text("Thread unavailable")
                        .font(.headline)
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(thread?.title ?? "Thread")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Community")
                    .environmentObject(session)
            }
        }
        .alert("Reported", isPresented: Binding(get: {
            reportMessage != nil
        }, set: { newValue in
            if !newValue {
                reportMessage = nil
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reportMessage ?? "")
        }
    }

    private func header(_ thread: DiscussionThread) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(thread.subtitle)
                .foregroundStyle(AppPalette.inkSoft)

            HStack(spacing: 12) {
                Label("\(discussionStore.commentCount(for: thread.id)) comments", systemImage: "text.bubble")
                Label(thread.lastActivityLabel, systemImage: "clock")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func pinnedPrompt(_ thread: DiscussionThread) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coach starter")
                .font(.subheadline.weight(.semibold))
            Text(thread.starterPrompt)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(AppPalette.sand.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var commentsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(comments) { comment in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(comment.authorName)
                                .font(.subheadline.weight(.semibold))
                            Text(comment.createdAt.relativeDisplayString)
                                .font(.caption)
                                .foregroundStyle(AppPalette.inkSoft)
                            if comment.editedAt != nil {
                                Text("Edited")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppPalette.clay)
                            }
                        }

                        Spacer()

                        if comment.isPinned {
                            Text("Coach")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppPalette.clay.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text(comment.body)
                        .foregroundStyle(AppPalette.ink)

                    HStack(spacing: 14) {
                        Button {
                            discussionStore.toggleLike(commentID: comment.id, in: threadID)
                        } label: {
                            Label("\(comment.likeCount)", systemImage: "hand.thumbsup")
                        }
                        .buttonStyle(.plain)

                        Button("Report") {
                            discussionStore.report(commentID: comment.id, in: threadID, reason: "manual")
                            reportMessage = "Thanks. The report was saved locally for moderation review."
                        }
                        .buttonStyle(.plain)

                        if session.currentUserID == comment.authorID {
                            Button("Edit") {
                                draft = comment.body
                                editingCommentID = comment.id
                            }
                            .buttonStyle(.plain)

                            Button("Delete", role: .destructive) {
                                if editingCommentID == comment.id {
                                    editingCommentID = nil
                                    draft = ""
                                }
                                discussionStore.deleteComment(commentID: comment.id, in: threadID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
                }
                .padding()
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editingCommentID == nil ? "Add your note" : "Edit your note")
                .font(.headline)

            if !session.canWriteCommunityComment {
                Text("Commenting requires All Access and Sign in with Apple.")
                    .foregroundStyle(AppPalette.inkSoft)

                Button("Unlock comment access") {
                    showPaywall = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                TextField("What felt good, what felt hard, and what would you change next time?", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4, reservesSpace: true)

                Button(editingCommentID == nil ? "Post Comment" : "Save Edit") {
                    let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedDraft.isEmpty else { return }

                    if let editingCommentID {
                        discussionStore.updateComment(commentID: editingCommentID, in: threadID, body: trimmedDraft)
                        self.editingCommentID = nil
                    } else {
                        discussionStore.addComment(
                            body: trimmedDraft,
                            to: threadID,
                            authorID: session.currentUserID,
                            authorName: session.displayName
                        )
                    }
                    draft = ""
                }
                .buttonStyle(.borderedProminent)

                if editingCommentID != nil {
                    Button("Cancel Edit") {
                        editingCommentID = nil
                        draft = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private extension Date {
    var relativeDisplayString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
