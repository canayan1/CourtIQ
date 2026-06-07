import Foundation

/// Bilingual copy for the Doubles feature (EN/TR). Kept self-contained
/// (rather than dozens of Localizable.strings keys) since the strings are
/// feature-local and many are keyed off enum values. Spanish falls back to
/// English (no es.lproj ships).
struct DoublesCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String) -> String {
        lang == .turkish ? tr : en
    }

    // MARK: Section / home
    var sectionTitle: String { t("Doubles", "Çiftler") }
    var homeTitle: String { t("Doubles compatibility", "Çiftler uyumu") }
    var homeSubtitle: String {
        t("See how you and a partner play together — and how to win as a team.",
          "Bir partnerle nasıl oynadığınızı gör — ve takım olarak nasıl kazanacağınızı.")
    }
    var emptyTitle: String { t("Test a partnership", "Bir partnerliği test et") }
    var emptyBody: String {
        t("Answer 8 quick questions each. Get a compatibility score, your team setup, and a plan.",
          "İkiniz de 8 hızlı soru yanıtlayın. Uyum skoru, takım kurulumu ve bir plan alın.")
    }
    var newTestCTA: String { t("New compatibility test", "Yeni uyum testi") }
    var partnershipsHeader: String { t("Your partnerships", "Partnerliklerin") }
    func testedOn(_ s: String) -> String { t("Tested \(s)", "Test: \(s)") }

    // MARK: Questionnaire
    var partnerNamePrompt: String { t("Who are you testing with?", "Kiminle test ediyorsun?") }
    var partnerNamePlaceholder: String { t("Partner's name", "Partnerin adı") }
    var youHeader: String { t("Your answers", "Senin cevapların") }
    func partnerHeader(_ name: String) -> String {
        t("\(name)'s answers", "\(name) cevapları")
    }
    var youShort: String { t("You", "Sen") }
    var next: String { t("Next", "İleri") }
    var back: String { t("Back", "Geri") }
    var seeResult: String { t("See result", "Sonucu gör") }
    // Hand-off + who-banner (single-device flow)
    func handoffTitle(_ name: String) -> String {
        t("Pass the phone to \(name)", "Telefonu \(name)'e ver")
    }
    func handoffBody(_ name: String) -> String {
        t("\(name) answers the same 8 questions as themselves. Your answers stay private.",
          "\(name) aynı 8 soruyu kendisi için yanıtlar. Senin cevapların gizli kalır.")
    }
    func handoffCTA(_ name: String) -> String {
        t("Start \(name)'s answers", "\(name) cevaplarına başla")
    }
    var answeringAsYou: String { t("Answering as you", "Sen olarak cevaplıyorsun") }
    func answeringAsPartner(_ name: String) -> String {
        t("Answering as \(name)", "\(name) olarak cevaplıyorsun")
    }

    var serveStrengthLabel: String { t("Serve strength", "Servis gücü") }
    var returnStrengthLabel: String { t("Return strength", "Return gücü") }
    var scaleWeak: String { t("Weak", "Zayıf") }
    var scaleStrong: String { t("Strong", "Güçlü") }

    /// Question prompt per dimension.
    func prompt(_ d: DoublesDimension) -> String {
        switch d {
        case .courtSide:   return t("Which return side do you prefer?", "Hangi return tarafını tercih edersin?")
        case .netBaseline: return t("Where are you most comfortable?", "Nerede daha rahatsın?")
        case .comms:       return t("How much do you talk on court?", "Kortta ne kadar konuşursun?")
        case .pressure:    return t("Under pressure, you tend to…", "Baskı altında genelde…")
        case .formation:   return t("I-formation / Australian?", "I-formation / Australian?")
        case .handedness:  return t("Which hand do you play with?", "Hangi elle oynarsın?")
        case .serve:       return "" // handled by serveStrengthLabel
        }
    }

    func sideOption(_ v: DoublesSide) -> String {
        switch v {
        case .deuce:  return t("Deuce", "Deuce")
        case .ad:     return t("Ad", "Ad")
        case .either: return t("No preference", "Farketmez")
        }
    }
    func netOption(_ v: NetComfort) -> String {
        switch v {
        case .net:      return t("I love the net", "Filede severim")
        case .mixed:    return t("Mixed / all-court", "Karma / all-court")
        case .baseline: return t("I prefer the baseline", "Baseline'ı tercih ederim")
        }
    }
    func commsOption(_ v: CommStyle) -> String {
        switch v {
        case .vocal:    return t("Very vocal", "Çok konuşkan")
        case .moderate: return t("Some", "Orta")
        case .quiet:    return t("Quiet", "Sessiz")
        }
    }
    func pressureOption(_ v: PressureStyle) -> String {
        switch v {
        case .goForIt:    return t("Go for winners", "Winner denerim")
        case .percentage: return t("Play percentages", "Yüzde oynarım")
        case .defend:     return t("Defend & reset", "Savunup sıfırlarım")
        }
    }
    func formationOption(_ v: FormationComfort) -> String {
        switch v {
        case .flexible:     return t("Comfortable", "Rahatım")
        case .standardOnly: return t("Standard only", "Sadece standart")
        }
    }
    func handOption(_ v: Handedness) -> String {
        switch v {
        case .right: return t("Right", "Sağ")
        case .left:  return t("Left", "Sol")
        }
    }

    // MARK: Result
    var compatibilityScore: String { t("Compatibility", "Uyum") }
    func band(_ b: CompatBand) -> String {
        switch b {
        case .strong:    return t("Strong fit", "Güçlü uyum")
        case .workable:  return t("Workable", "Çalışılır")
        case .needsPlan: return t("Needs a plan", "Plan gerek")
        }
    }
    func bandBlurb(_ b: CompatBand) -> String {
        switch b {
        case .strong:    return t("Your styles complement each other. Lean into it.",
                                  "Tarzlarınız birbirini tamamlıyor. Üstüne gidin.")
        case .workable:  return t("A solid base with a few things to align on.",
                                  "Sağlam bir temel — birkaç noktada anlaşın.")
        case .needsPlan: return t("Some clashes to manage. The plan below helps.",
                                  "Yönetilecek çakışmalar var. Aşağıdaki plan yardımcı olur.")
        }
    }

    func dimTitle(_ d: DoublesDimension) -> String {
        switch d {
        case .courtSide:   return t("Court sides", "Kort tarafları")
        case .netBaseline: return t("Net coverage", "File kapsama")
        case .comms:       return t("Communication", "İletişim")
        case .pressure:    return t("Pressure style", "Baskı tarzı")
        case .formation:   return t("Formation range", "Formasyon esnekliği")
        case .handedness:  return t("Handedness", "El kombinasyonu")
        case .serve:       return t("Serving", "Servis")
        }
    }

    /// Short coaching note per dimension + rating.
    func dimNote(_ d: DoublesDimension, _ r: DimensionRating) -> String {
        switch (d, r) {
        case (.courtSide, .green):  return t("Your return sides fit cleanly.", "Return taraflarınız temiz oturuyor.")
        case (.courtSide, .yellow): return t("Both flexible — just agree on sides.", "İkiniz de esneksiniz — tarafları konuşun.")
        case (.courtSide, .red):    return t("You both want the same side; one must adapt.", "İkiniz de aynı tarafı istiyorsunuz; biri uyum sağlamalı.")
        case (.netBaseline, .green):return t("Good balance — someone owns the net.", "İyi denge — biri fileyi sahipleniyor.")
        case (.netBaseline, .yellow):return t("Manageable, but cover the net together.", "İdare eder ama fileyi birlikte kapatın.")
        case (.netBaseline, .red):  return t("Both baseline-heavy — weak at the net.", "İkiniz de baseline ağırlıklı — filede zayıf.")
        case (.comms, .green):      return t("You'll talk enough to avoid confusion.", "Kafa karışıklığını önleyecek kadar konuşursunuz.")
        case (.comms, .yellow):     return t("One of you should make the calls.", "Biriniz çağrıları yapmalı.")
        case (.comms, .red):        return t("Both quiet — middle balls will get messy.", "İkiniz de sessiz — orta toplar karışır.")
        case (.pressure, .green):   return t("Matched risk appetite.", "Risk iştahınız eşleşiyor.")
        case (.pressure, .yellow):  return t("Different under pressure — agree who fires.", "Baskı altında farklısınız — kim riske girer konuşun.")
        case (.pressure, .red):     return t("Opposite instincts under pressure.", "Baskı altında zıt içgüdüler.")
        case (.formation, .green):  return t("You can both run I-formation / Australian.", "İkiniz de I-formation / Australian oynayabilirsiniz.")
        case (.formation, .yellow): return t("Limited tactical variety for now.", "Şimdilik sınırlı taktik çeşitlilik.")
        case (.formation, .red):    return t("Standard formation only.", "Sadece standart formasyon.")
        case (.handedness, .green): return t("Lefty + righty — two forehands in the middle.", "Sol + sağ — ortada iki forehand.")
        case (.handedness, .yellow):return t("Same hand — mind the backhand in the middle.", "Aynı el — ortadaki backhand'e dikkat.")
        case (.handedness, .red):   return t("Same hand.", "Aynı el.")
        case (.serve, .green):      return t("Two dependable serves.", "İki güvenilir servis.")
        case (.serve, .yellow):     return t("Serving is a work-in-progress.", "Servis gelişime açık.")
        case (.serve, .red):        return t("Serve is a weak point for the team.", "Servis takım için zayıf nokta.")
        }
    }

    // MARK: Team setup
    var teamSetupHeader: String { t("Your team setup", "Takım kurulumun") }
    func serveFirst(_ name: String) -> String { t("\(name) serves first", "Önce \(name) servis atar") }
    func returnSides(deuce: String, ad: String) -> String {
        t("\(deuce) returns deuce · \(ad) returns ad", "\(deuce) deuce döner · \(ad) ad döner")
    }
    func formation(_ f: StartingFormation) -> String {
        switch f {
        case .bothUp:            return t("Start both at the net when you can.", "Fırsat buldukça ikiniz de filede başlayın.")
        case .oneUpOneBackPoach: return t("One up, one back — poach the middle.", "Biri önde biri arkada — ortayı poach'la.")
        case .startBackApproach: return t("Start back, then approach together on short balls.", "Arkada başlayın, kısa toplarda birlikte file alın.")
        }
    }

    var strengthsHeader: String { t("Strengths", "Güçlü yönler") }
    var watchOutsHeader: String { t("Watch-outs", "Dikkat edilecekler") }

    // MARK: Prep sheet
    var prepHeader: String { t("Practice plan", "Antrenman planı") }
    func prepTip(_ d: DoublesDimension) -> String {
        switch d {
        case .courtSide:   return t("Rehearse the I-formation so the server's partner doesn't telegraph the side.",
                                    "I-formation'ı çalışın ki servis atanın partneri tarafı ele vermesin.")
        case .netBaseline: return t("Drill approaching together on short balls and closing the net as a pair.",
                                    "Kısa toplarda birlikte file alıp çift olarak fileyi kapatmayı çalışın.")
        case .comms:       return t("Pre-agree: the middle ball belongs to the forehand / the player moving to it.",
                                    "Önceden anlaşın: orta top forehand'in / o yöne hareket edenin.")
        case .pressure:    return t("Agree who goes for the big shot on key points so you don't both bail or both gamble.",
                                    "Kritik puanlarda büyük vuruşu kim deneyecek konuşun — ikiniz de kaçmayın ya da ikiniz de riske girmeyin.")
        case .formation:   return t("Add I-formation and Australian to your toolkit against strong cross-court returners.",
                                    "Güçlü çapraz return'cülere karşı I-formation ve Australian'ı dağarcığınıza ekleyin.")
        case .handedness:  return t("Cover the middle deliberately — decide whose shot it is before the point.",
                                    "Ortayı bilinçli kapatın — top kimin, puandan önce belirleyin.")
        case .serve:       return t("Build first-serve consistency; a steady serve sets up the whole point in doubles.",
                                    "İlk servis istikrarını geliştirin; çiftlerde sağlam servis tüm puanı kurar.")
        }
    }

    // MARK: AI plan (premium teaser; full feature in Step 6)
    var aiPlanTitle: String { t("AI doubles game-plan", "AI çiftler oyun planı") }
    var aiPlanBody: String {
        t("A personalized plan from the AI Coach — built around your two profiles, your matches, and your weak spots.",
          "AI Koç'tan kişisel bir plan — iki profilinize, maçlarınıza ve zayıf yönlerinize göre.")
    }
    var aiPlanCTA: String { t("Get the AI game-plan", "AI oyun planını al") }
    var aiPlanComingSoon: String { t("Coming soon", "Yakında") }

    // MARK: misc
    var save: String { t("Save partnership", "Partnerliği kaydet") }
    var done: String { t("Done", "Bitti") }
    var cancel: String { t("Cancel", "İptal") }
    var deletePartnership: String { t("Delete", "Sil") }
}
