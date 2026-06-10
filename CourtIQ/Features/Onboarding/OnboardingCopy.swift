import Foundation

/// Bilingual copy for the high-conversion onboarding flow (EN/TR). Mirrors the
/// `TennisProfileCopy` pattern: an inline `t(en, tr)` accessor. Spanish falls
/// back to English. Strings here cover only the *new* onboarding screens — the
/// Tennis Profile questions/levels/archetypes are resolved via
/// `TennisProfileCopy`, which this flow reuses.
struct OnboardingCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String) -> String { lang == .turkish ? tr : en }

    // MARK: Navigation
    var next: String { t("Continue", "Devam") }
    var back: String { t("Back", "Geri") }
    var getStarted: String { t("Get started", "Başla") }

    // MARK: 1 — Welcome / hook
    var welcomeTitle: String {
        t("Train the tennis brain that wins matches",
          "Maç kazandıran tenis beynini eğit")
    }
    var welcomeBullets: [String] {
        [
            t("Real match scenarios, not just stroke tips",
              "Sadece vuruş ipuçları değil — gerçek maç senaryoları"),
            t("A coach that learns your game and remembers it",
              "Oyununu öğrenen ve hatırlayan bir koç"),
            t("Build true Tennis IQ — the decisions that win points",
              "Gerçek Tenis IQ'su geliştir — puan kazandıran kararlar"),
        ]
    }

    // MARK: 2 — Goal
    var goalQuestion: String { t("What's your #1 tennis goal?", "Bir numaralı tenis hedefin ne?") }
    func goalOption(_ g: OnboardingGoal) -> String {
        switch g {
        case .winMatches:   return t("Win more matches", "Daha çok maç kazanmak")
        case .fixWeakness:  return t("Fix specific weaknesses", "Belirli zayıflıkları gidermek")
        case .strategy:     return t("Understand strategy & tactics", "Strateji ve taktiği anlamak")
        case .climbLevel:   return t("Climb my level (NTRP)", "Seviye atlamak (NTRP)")
        }
    }

    // MARK: 8 — Weaknesses (pain points, multi-select)
    var weaknessQuestion: String { t("Where do you lose points?", "Puanları nerede kaybediyorsun?") }
    var weaknessHint: String { t("Pick all that apply.", "Geçerli olanların hepsini seç.") }
    func weaknessOption(_ w: OnboardingWeakness) -> String {
        switch w {
        case .backhand:      return t("Backhand", "Backhand")
        case .serve:         return t("Serve", "Servis")
        case .netPlay:       return t("Net play", "File oyunu")
        case .ret:           return t("Return", "Return")
        case .shotSelection: return t("Shot selection", "Vuruş seçimi")
        case .mentalGame:    return t("Mental game", "Zihinsel oyun")
        case .fitness:       return t("Fitness", "Kondisyon")
        }
    }

    // MARK: 9 — Behavioral sliders (two-statement, Noom-style)
    var slidersTitle: String { t("How do you play the big points?", "Önemli puanları nasıl oynarsın?") }
    var slidersIntro: String { t("Drag toward the statement that fits you.", "Sana uyan ifadeye doğru kaydır.") }

    var sliderPatienceLeft: String { t("I rush big points", "Önemli puanlarda acele ederim") }
    var sliderPatienceRight: String { t("I stay patient", "Sabırlı kalırım") }

    var sliderTacticsLeft: String { t("I just react", "Sadece tepki veririm") }
    var sliderTacticsRight: String { t("I play tactically", "Taktiksel oynarım") }

    var sliderAggressionLeft: String { t("I play it safe", "Garantiye oynarım") }
    var sliderAggressionRight: String { t("I go for my shots", "Vuruşlarımı denerim") }

    // MARK: 11 — Commitment
    var commitmentQuestion: String { t("How many scenario drills a day?", "Günde kaç senaryo çalışması?") }
    func commitmentFeedback(_ perDay: Int) -> String {
        let monthly = perDay * 30
        return t("\(perDay)/day → ~\(monthly) scenarios this month",
                 "Günde \(perDay) → bu ay ~\(monthly) senaryo")
    }
    func perDayLabel(_ perDay: Int) -> String {
        t("\(perDay)/day", "Günde \(perDay)")
    }

    // MARK: 12 — Labor illusion (building plan)
    var buildingTitle: String { t("Building your plan", "Planın hazırlanıyor") }
    func buildAnalyzingLevel(_ levelTitle: String) -> String {
        t("Analyzing your level: \(levelTitle)…", "Seviyeni inceliyoruz: \(levelTitle)…")
    }
    func buildMatchingDrills(_ weakness: String) -> String {
        t("Matching scenario drills to your \(weakness)…", "Senaryo çalışmalarını \(weakness) ile eşliyoruz…")
    }
    func buildCalibrating(_ perDay: Int) -> String {
        t("Calibrating your \(perDay)/day plan…", "Günde \(perDay)'lik planını ayarlıyoruz…")
    }
    var buildFinalizing: String { t("Finalizing your Tennis Profile…", "Tenis Profilini tamamlıyoruz…") }
    var buildGenericFocus: String { t("game", "oyunun") }

    // MARK: 13 — Result reveal
    var resultReadyKicker: String { t("YOUR PLAN IS READY", "PLANIN HAZIR") }
    func resultPlanLine(goal: String, weakness: String) -> String {
        t("Your plan to fix your \(weakness) and \(goal) is ready.",
          "\(weakness) sorununu çözüp \(goal) için planın hazır.")
    }
    func resultGoalPhrase(_ g: OnboardingGoal) -> String {
        switch g {
        case .winMatches:  return t("win more matches", "daha çok maç kazanman")
        case .fixWeakness: return t("close your gaps", "açıklarını kapatman")
        case .strategy:    return t("master strategy", "stratejiyi öğrenmen")
        case .climbLevel:  return t("climb your level", "seviye atlaman")
        }
    }
    var tennisIQHeader: String { t("Your Tennis IQ", "Tenis IQ'n") }
    var iqToday: String { t("Today", "Bugün") }
    func iqTarget(_ timeframe: String) -> String { t("In \(timeframe)", "\(timeframe) içinde") }
    var iqTimeframe: String { t("8 weeks", "8 hafta") }
    var iqProjectionNote: String {
        t("Stick with your daily scenarios and your decision-making climbs fast.",
          "Günlük senaryolarına devam et — karar verme hızla yükselir.")
    }
    var resultContinue: String { t("Continue", "Devam") }

    // MARK: Result section headers (reused alongside TennisProfileCopy)
    var levelHeader: String { t("Your level", "Seviyen") }
    var styleHeader: String { t("Your style", "Stilin") }
    var strengthsHeader: String { t("Your strengths", "Güçlü yönlerin") }
    var growthHeader: String { t("Grow these next", "Sıradaki gelişim") }

    // MARK: 14 — Leave a review
    var reviewTitle: String { t("Loving your plan?", "Planını sevdin mi?") }
    var reviewBody: String {
        t("A quick review helps DropVolley grow — and helps other players find it. 🎾",
          "Kısa bir değerlendirme DropVolley'in büyümesine — ve başka oyuncuların bulmasına — çok yardımcı olur. 🎾")
    }
    var reviewRate: String { t("Rate DropVolley", "DropVolley'i değerlendir") }
    var reviewLater: String { t("Maybe later", "Belki sonra") }

    // MARK: 15 — Evidence carousel ("why DropVolley is different")
    struct EvidenceSlide { let headline: String; let support: String; let symbol: String }
    var evidenceSlides: [EvidenceSlide] {
        [
            EvidenceSlide(
                headline: t("See your swing like a coach does",
                            "Vuruşunu bir koç gibi gör"),
                support: t("Film a quick swing and DropVolley's AI breaks down your technique — grip, contact point, follow-through.",
                           "Kısa bir vuruş çek; DropVolley'in AI'ı tekniğini çözümlesin — grip, temas noktası, takip."),
                symbol: "video.fill"
            ),
            EvidenceSlide(
                headline: t("Other apps fix your strokes.\nDropVolley fixes your decisions.",
                            "Diğer uygulamalar vuruşunu düzeltir.\nDropVolley kararlarını düzeltir."),
                support: t("Matches are won between the ears — by the shot you choose, not just the one you hit.",
                           "Maçlar kafada kazanılır — vurduğun değil, seçtiğin vuruşla."),
                symbol: "brain.head.profile"
            ),
            EvidenceSlide(
                headline: t("A coach that remembers\nevery match.",
                            "Her maçı hatırlayan\nbir koç."),
                support: t("Your AI Coach knows your level, your style, and your last result — and coaches from it.",
                           "AI Koç'un seviyeni, stilini ve son skorunu bilir — ona göre yönlendirir."),
                symbol: "brain.head.profile"
            ),
            EvidenceSlide(
                headline: t("Know your real game —\nnot just a rating.",
                            "Gerçek oyununu bil —\nsadece bir puanı değil."),
                support: t("Your Tennis Profile shows exactly where you stand and what to work on next.",
                           "Tenis Profilin tam olarak nerede olduğunu ve sıradaki adımı gösterir."),
                symbol: "chart.bar.fill"
            ),
        ]
    }
    var seeMyPlan: String { t("See my plan", "Planımı gör") }
}

// MARK: - Flow-local answer types (not part of the Tennis Profile engine)

/// The framing goal asked up front. Stored locally in the flow; used to tailor
/// the labor-illusion and result copy (it does not feed the deterministic
/// `TennisProfile` scorer).
enum OnboardingGoal: String, CaseIterable, Identifiable {
    case winMatches
    case fixWeakness
    case strategy
    case climbLevel
    var id: String { rawValue }
}

/// Self-reported pain points (multi-select). Reinforces the stroke ratings and
/// drives the labor-illusion / result copy. Not a scorer input.
enum OnboardingWeakness: String, CaseIterable, Identifiable {
    case backhand
    case serve
    case netPlay
    case ret
    case shotSelection
    case mentalGame
    case fitness
    var id: String { rawValue }
}
