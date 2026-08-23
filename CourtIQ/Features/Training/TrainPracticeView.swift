import SwiftUI

/// The Drills screen in the Train tab: the court-tap Drill and (when one is
/// available) the day's Pro shot pattern.
///
/// The six premium-locked category quizzes that used to head this screen are
/// gone. Tennis IQ now owns every scenario through the free skill path, so
/// keeping a paywalled copy here meant one name pointing at two screens — and
/// the worse of the two was the paid one.
struct TrainPracticeView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager
    @EnvironmentObject private var proShotManager: ProShotPatternsManager

    @State private var showDrill = false
    @State private var showProShot = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    Haptics.tap()
                    showDrill = true
                } label: {
                    LockableTile(sfSymbol: "scope",
                                 title: lang.t("train.drill_label"),
                                 minHeight: 132,
                                 photo: "PhotoFootwork")
                }
                .buttonStyle(PressableCardStyle())

                if proShotManager.todaysPattern != nil {
                    Button {
                        Haptics.tap()
                        showProShot = true
                    } label: {
                        LockableTile(sfSymbol: "trophy.fill",
                                     title: lang.t("train.pro_shot_label"),
                                     minHeight: 132,
                                     photo: "PhotoGear")
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("train.drills"))
        .fullScreenCover(isPresented: $showDrill) {
            NavigationStack {
                CourtTapDrillView()
                    .environmentObject(lang)
                    .environmentObject(drillManager)
            }
        }
        .fullScreenCover(isPresented: $showProShot) {
            if let pattern = proShotManager.todaysPattern {
                ProShotAnimationView(pattern: pattern)
                    .environmentObject(lang)
            }
        }
    }
}
