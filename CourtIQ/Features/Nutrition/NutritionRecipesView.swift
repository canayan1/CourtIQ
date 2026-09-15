import SwiftUI

/// Six questions, then the recipes that fit — ranked by how many of the
/// player's answers each one matches, with that number shown on the card
/// so the ranking is never a mystery. Static content, no model.
struct NutritionRecipesView: View {
    let book: NutritionRecipeBook

    @EnvironmentObject private var lang: LanguageManager
    /// Answers persist so the list is one tap away next time.
    @AppStorage("CourtIQ.Nutrition.RecipeAnswers") private var storedAnswers = ""
    @State private var answers: [String: String] = [:]
    @State private var showResults = false

    private var allAnswered: Bool { book.quiz.allSatisfy { answers[$0.id] != nil } }

    private var chosenTags: Set<String> {
        Set(book.quiz.flatMap { q in q.options.filter { $0.id == answers[q.id] }.flatMap(\.tags) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if showResults { results } else { quiz }
                Text(lang.t("nutrition.disclaimer"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("nutrition.recipes_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if answers.isEmpty, !storedAnswers.isEmpty,
               let data = storedAnswers.data(using: .utf8),
               let saved = try? JSONDecoder().decode([String: String].self, from: data) {
                answers = saved
                showResults = book.quiz.allSatisfy { saved[$0.id] != nil }
            }
        }
    }

    // MARK: Quiz

    private var quiz: some View {
        VStack(alignment: .leading, spacing: 22) {
            Eyebrow(lang.t("nutrition.recipes_quiz_eyebrow"))
            ForEach(book.quiz) { q in
                VStack(alignment: .leading, spacing: 10) {
                    Text(q.question)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                    FlowLayout(spacing: 8) {
                        ForEach(q.options) { option in
                            let selected = answers[q.id] == option.id
                            Button {
                                Haptics.tap()
                                answers[q.id] = option.id
                            } label: {
                                Text(option.label)
                                    .font(.subheadline.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .foregroundStyle(selected ? .white : AppPalette.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(selected ? AppPalette.clay : AppPalette.parchment, in: Capsule())
                                    .overlay(Capsule().stroke(selected ? AppPalette.clay : AppPalette.sand, lineWidth: 1))
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                }
            }
            PrimaryButton(title: lang.t("nutrition.recipes_show"), icon: "arrow.right", enabled: allAnswered) {
                if let data = try? JSONEncoder().encode(answers), let text = String(data: data, encoding: .utf8) {
                    storedAnswers = text
                }
                withAnimation { showResults = true }
            }
        }
    }

    // MARK: Results

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(lang.t("nutrition.recipes_title"))
                Spacer()
                Button(lang.t("nutrition.recipes_retake")) {
                    Haptics.tap()
                    withAnimation { showResults = false }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.clayText)
            }
            ForEach(book.ranked(for: chosenTags), id: \.recipe.id) { item in
                NavigationLink {
                    NutritionRecipeDetailView(recipe: item.recipe)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lang.t("nutrition.recipe_when_\(item.recipe.when)"))
                                .font(.caption2.weight(.heavy)).kerning(0.6)
                                .foregroundStyle(AppPalette.mossDeep)
                            Text(item.recipe.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppPalette.ink)
                            Text(String(format: lang.t("nutrition.recipes_matches_fmt"), item.matches, item.recipe.prepMinutes))
                                .font(.caption)
                                .foregroundStyle(AppPalette.inkSoft)
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
        }
    }
}

struct NutritionRecipeDetailView: View {
    let recipe: NutritionRecipeBook.Recipe
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Text(lang.t("nutrition.recipe_when_\(recipe.when)"))
                    Text("·")
                    Text("\(recipe.prepMinutes) min")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)

                section(lang.t("nutrition.recipe_ingredients")) {
                    ForEach(recipe.ingredients, id: \.self) { ing in
                        HStack(alignment: .top) {
                            Text(ing.item).foregroundStyle(AppPalette.ink)
                            Spacer()
                            Text(ing.amount).foregroundStyle(AppPalette.inkSoft)
                        }
                        .font(.subheadline)
                    }
                }
                section(lang.t("nutrition.recipe_steps")) {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.system(.caption, design: .rounded).weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(AppPalette.clay, in: Circle())
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(lang.t("nutrition.recipe_why"), tint: AppPalette.mossDeep)
                    Text(recipe.why)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !recipe.swap.isEmpty {
                        Text("\(lang.t("nutrition.recipe_swap")): \(recipe.swap)")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface(fill: AppPalette.mossTint.opacity(0.45), stroke: AppPalette.moss.opacity(0.35), cornerRadius: 18)
                Text(lang.t("nutrition.disclaimer"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(title)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 16)
    }
}
