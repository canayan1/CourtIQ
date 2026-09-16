import SwiftUI

/// The written guide: a list of sections, each opening to its body, key
/// points and the sources it rests on. Sources are shown, not hidden — a
/// player should be able to see that "eat 1–4 hours before" comes from a
/// position stand and not from us.
struct NutritionGuideView: View {
    let guide: NutritionGuide
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(guide.sections) { section in
                    NavigationLink {
                        NutritionGuideSectionView(section: section)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppPalette.ink)
                                Text(section.summary)
                                    .font(.footnote)
                                    .foregroundStyle(AppPalette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
                                .padding(.top, 4)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface(cornerRadius: 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableCardStyle())
                }
                Text(lang.t("nutrition.disclaimer"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("nutrition.guide_title"))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("Nutrition Guide")
    }
}

struct NutritionGuideSectionView: View {
    let section: NutritionGuide.Section
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(section.summary)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(section.body, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.body)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(lang.t("nutrition.guide_key_points"))
                    ForEach(section.keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppPalette.moss)
                            Text(point)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface(fill: AppPalette.mossTint.opacity(0.45), stroke: AppPalette.moss.opacity(0.35), cornerRadius: 18)
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(lang.t("nutrition.guide_sources"))
                    ForEach(section.sources, id: \.self) { source in
                        if let url = URL(string: source.url) {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                    Text(source.label)
                                        .multilineTextAlignment(.leading)
                                }
                                .font(.footnote)
                                .foregroundStyle(AppPalette.clayText)
                            }
                        }
                    }
                }
                Text(lang.t("nutrition.disclaimer"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("Nutrition Guide Section")
    }
}
