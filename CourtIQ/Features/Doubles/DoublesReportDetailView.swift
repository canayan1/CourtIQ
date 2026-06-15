import SwiftUI

/// A single saved compatibility report: the score (prominently), the date, and
/// the analysis text. Reuses `DoublesScoreView` + `SwingReportText`.
struct DoublesReportDetailView: View {
    @EnvironmentObject private var lang: LanguageManager

    let report: DoublesReport

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let score = report.score {
                        DoublesScoreView(score: score, copy: copy)
                            .frame(maxWidth: .infinity)
                    }

                    Text(copy.relativeDate(report.date))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)

                    SwingReportText(text: report.reportText)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(20)
            }
        }
        .navigationTitle(copy.reportTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
