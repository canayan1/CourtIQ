import SwiftUI
import AVKit

/// A browsable list of the user's saved swing analyses, newest first. Each row
/// shows the saved thumbnail, the stroke label, a score badge, and a relative
/// date. Tapping a row opens `SwingReportDetailView`.
struct SwingHistoryView: View {
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var store = SwingAnalysisStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var copy: SwingAnalysisCopy { SwingAnalysisCopy(lang: lang.language) }

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            if store.records.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle(copy.historyNavTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var list: some View {
        List {
            ForEach(Array(store.records.enumerated()), id: \.element.id) { index, record in
                ZStack {
                    NavigationLink {
                        SwingReportDetailView(record: record)
                    } label: { EmptyView() }
                    .opacity(0)

                    row(record)
                }
                .reveal(appeared: appeared, index: index, reduceMotion: reduceMotion)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                for index in offsets {
                    store.delete(store.records[index])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onAppear {
            if reduceMotion { appeared = true }
            else if !appeared { withAnimation(Motion.entrance) { appeared = true } }
        }
    }

    private func row(_ record: SwingAnalysisRecord) -> some View {
        HStack(spacing: 12) {
            thumbnail(record)

            VStack(alignment: .leading, spacing: 6) {
                Text(strokeLabel(record))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(copy.relativeDate(record.date))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }

            Spacer(minLength: 0)

            if let score = record.score {
                SwingScoreBadge(score: score, copy: copy)
            }
        }
        .padding(12)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func thumbnail(_ record: SwingAnalysisRecord) -> some View {
        if let image = store.thumbnailImage(for: record) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppPalette.moss.opacity(0.12))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "figure.tennis")
                        .font(.title3)
                        .foregroundStyle(AppPalette.moss)
                )
        }
    }

    private func strokeLabel(_ record: SwingAnalysisRecord) -> String {
        if let stroke = record.stroke { return copy.stroke(stroke) }
        return record.strokeRaw.capitalized
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .appFont(40, design: .default)
                .foregroundStyle(AppPalette.moss)
            Text(copy.historyEmpty)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Detail

/// A single saved swing report: the score (prominently), stroke + date, an
/// inline video player for the saved clip, the analysis text, and a delete
/// button. Reuses the shared `SwingReportText` / `SwingScoreView`.
struct SwingReportDetailView: View {
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var store = SwingAnalysisStore.shared
    @Environment(\.dismiss) private var dismiss

    let record: SwingAnalysisRecord

    private var copy: SwingAnalysisCopy { SwingAnalysisCopy(lang: lang.language) }

    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let score = record.score {
                        SwingScoreView(score: score, copy: copy)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(strokeLabel)
                            .font(.title3.bold())
                            .foregroundStyle(AppPalette.ink)
                        Text(copy.relativeDate(record.date))
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                    }

                    videoPlayer

                    AIReportSectionsView(text: record.analysisText)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(copy.deleteCTA, systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .navigationTitle(copy.savedVideoTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(copy.deleteCTA, isPresented: $showDeleteConfirm) {
            Button(copy.deleteCTA, role: .destructive) {
                store.delete(record)
                dismiss()
            }
            Button(copy.cancelCTA, role: .cancel) { }
        }
    }

    @ViewBuilder
    private var videoPlayer: some View {
        let url = store.videoURL(for: record)
        if FileManager.default.fileExists(atPath: url.path) {
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var strokeLabel: String {
        if let stroke = record.stroke { return copy.stroke(stroke) }
        return record.strokeRaw.capitalized
    }
}

// MARK: - Staggered entrance modifier

private extension View {
    /// Mirrors the Train hub / Mobility library tactile staggered entrance;
    /// Reduce-Motion safe (fades in place when Reduce Motion is on).
    @ViewBuilder
    func reveal(appeared: Bool, index: Int, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self.opacity(appeared ? 1 : 0)
        } else {
            self
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .scaleEffect(appeared ? 1 : 0.97)
                .animation(Motion.entrance.delay(Double(index) * Motion.stagger),
                           value: appeared)
        }
    }
}
