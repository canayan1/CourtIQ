import SwiftUI

/// The receiving half of a head-to-head: someone sent five scenarios and the
/// score they got. You play the same five, then the two numbers sit side by
/// side.
///
/// Nothing here is social in the app sense — there is no thread, no profile and
/// no one to follow. Two people, five questions, one link.
///
/// It opens in one of two states. An invitation is played. A reply — someone
/// answering the challenge you sent — is already finished, so it opens on the
/// result and asks nothing: the five scenarios in it are five this player has
/// seen, and inviting them to "beat" a score by re-answering questions they
/// know the answers to would be a scoreboard, not a contest.
struct ChallengeView: View {
    let challenge: TennisChallenge

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var iq = TennisIQManager.shared

    private enum Phase { case intro, playing, result }
    @State private var phase: Phase
    @State private var myScore: Int

    init(challenge: TennisChallenge) {
        self.challenge = challenge
        _phase = State(initialValue: challenge.isReply ? .result : .intro)
        _myScore = State(initialValue: 0)
    }

    /// On an invitation, "mine" is the score just played. On a reply it is the
    /// score this player already sent — they are the original challenger, and
    /// the link is their own number coming back with an answer beside it.
    private var mine: Int { challenge.isReply ? challenge.challengerScore : myScore }
    private var theirs: Int { challenge.replierScore ?? challenge.challengerScore }

    /// Resolved once, so the same five questions are asked in the same order
    /// the challenger answered them.
    private var questions: [QuizQuestion] {
        let byID = Dictionary(uniqueKeysWithValues: iq.bank.map { ($0.id, $0) })
        return challenge.questionIDs.compactMap { byID[$0] }
    }

    var body: some View {
        NavigationStack {
            Group {
                if questions.count != TennisChallenge.length {
                    // The link named a scenario this build no longer has.
                    // Say so plainly rather than quietly playing four.
                    unavailable
                } else {
                    switch phase {
                    case .intro:   intro
                    case .playing:
                        QuizView(quiz: Quiz(id: "challenge", title: lang.t("challenge.title"),
                                            questions: questions),
                                 title: lang.t("challenge.title")) { summary in
                            myScore = summary.score
                            iq.recordPractice(results: summary.perQuestionResults ?? [:])
                            AppAnalytics.shared.log(AnalyticsEvent.challengeCompleted,
                                                    ["mine": summary.score,
                                                     "theirs": challenge.challengerScore])
                            withAnimation(Motion.entrance) { phase = .result }
                        }
                    case .result:  result
                    }
                }
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("challenge.title"))
            .navigationBarTitleDisplayMode(.inline)
            .trackScreen("Challenge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("common.done")) { dismiss() }
                        .foregroundStyle(AppPalette.clay)
                }
            }
        }
    }

    // MARK: Intro

    private var intro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(lang.t("challenge.eyebrow"))
                Text(String(format: lang.t("challenge.intro_fmt"),
                            challenge.challengerScore, TennisChallenge.length))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.t("challenge.intro_body"))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: lang.t("challenge.start"), icon: "figure.tennis") {
                    AppAnalytics.shared.log(AnalyticsEvent.challengeStarted,
                                            ["theirs": challenge.challengerScore])
                    withAnimation(Motion.entrance) { phase = .playing }
                }
            }
            .padding(20)
        }
    }

    // MARK: Result

    private var result: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(lang.t(challenge.isReply ? "challenge.reply_eyebrow" : "challenge.result_eyebrow"))
                Text(verdict)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    scoreTile(lang.t("challenge.you"), mine, mine: true)
                    scoreTile(lang.t("challenge.them"), theirs, mine: false)
                }

                // The reply closes the loop, and closes it once. A reply to a
                // reply would be the same five questions a third time, with
                // both players now knowing every answer.
                if !challenge.isReply, let reply = challenge.reply(withMyScore: myScore) {
                    ShareLink(item: reply.url,
                              message: Text(String(format: lang.t("challenge.share_reply_fmt"),
                                                   myScore, TennisChallenge.length))) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                            Text(lang.t("challenge.send_back"))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.shared.log(AnalyticsEvent.challengeShared, ["from": "reply"])
                    })
                }

                Text(lang.t(challenge.isReply ? "challenge.reply_footer" : "challenge.result_footer"))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
    }

    private var verdict: String {
        if mine > theirs { return lang.t("challenge.verdict_win") }
        if mine < theirs { return lang.t("challenge.verdict_lose") }
        return lang.t("challenge.verdict_draw")
    }

    private func scoreTile(_ label: String, _ score: Int, mine: Bool) -> some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(mine ? AppPalette.clay : AppPalette.ink)
                .monospacedDigit()
            Text("/ \(TennisChallenge.length)")
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .cardSurface(cornerRadius: 18)
    }

    private var unavailable: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
                .foregroundStyle(AppPalette.inkSoft)
            Text(lang.t("challenge.unavailable"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
    }
}
