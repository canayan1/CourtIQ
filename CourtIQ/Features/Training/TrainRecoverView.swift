import SwiftUI

/// Recover level of the Train tree: a single Mobility row that pushes the
/// existing MobilityLibraryView.
struct TrainRecoverView: View {
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink {
                    MobilityLibraryView()
                } label: {
                    iconRow(systemImage: "figure.walk",
                            title: lang.t("train.mobility_label"))
                }
                .buttonStyle(PressableCardStyle())
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("train.recover"))
    }

    private func iconRow(systemImage: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(AppPalette.clay)
                .frame(width: 28)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
