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
    var skip: String { t("Skip", "Atla") }
    var showcaseContinue: String { t("Continue", "Devam") }

    // MARK: 0 — Hook / positioning (opens the app)
    var hookEyebrow: String { t("DROPVOLLEY", "DROPVOLLEY") }
    var hookTitle: String { t("Three ways to get better at tennis.", "Teniste gelişmenin üç yolu.") }
    var hookSubtitle: String {
        t("Film a swing and get it read. Hit the wall and get it counted. Learn the tactics that win points.",
          "Vuruşunu çek, okunsun. Duvara vur, sayılsın. Puan kazandıran taktikleri öğren.")
    }

    // MARK: Feature showcase — one slide per pillar, each a live sample
    var showcaseCoachPillarEyebrow: String { t("COACH", "KOÇ") }
    var showcaseCoachPillarHeadline: String { t("Your swing, reviewed", "Vuruşun, incelenmiş") }
    var showcaseWallEyebrow: String { t("WALL", "DUVAR") }
    var showcaseWallHeadline: String { t("The wall counts now", "Duvar artık sayıyor") }
    var showcaseWallReps: String { t("reps", "tekrar") }
    var showcaseWallVerdict: String { t("Level cleared", "Seviye geçildi") }
    var showcaseWallCaption: String {
        t("Prop the phone behind you. It watches you swing and grades the rung.",
          "Telefonu arkana koy. Vuruşunu izler, basamağı notlar.")
    }
    var showcaseTacticsEyebrow: String { t("TACTICS", "TAKTİK") }
    var showcaseTacticsHeadline: String { t("Learn tactics like a language", "Taktiği bir dil gibi öğren") }
    var showcaseTacticsBubble: String {
        t("Cross-court is the safer ball. Here's why — and when to break the rule.",
          "Çapraz top daha güvenli. İşte nedeni — ve kuralı ne zaman bozacağın.")
    }
    var showcaseTacticsCaption: String { t("30 lessons · 156 scenarios · chapter 1 free", "30 ders · 156 senaryo · 1. bölüm ücretsiz") }

    var showcaseSwingEyebrow: String { t("SWING", "SWING") }
    var showcaseSwingHeadline: String {
        t("Your swing, two ways", "Vuruşun, iki yol")
    }
    var showcaseSwingSampleTitle: String { t("Forehand · Sample", "Forehand · Örnek") }
    var showcaseSwingBullet1: String {
        t("Clean unit turn — shoulders coil early, giving you time to load.",
          "Temiz gövde dönüşü — omuzlar erken kuruluyor, yüklenmeye zaman tanıyor.")
    }
    var showcaseSwingBullet2: String {
        t("Follow-through cuts short — finish over the shoulder for more topspin.",
          "Bitiriş kısa kalıyor — daha çok topspin için omuz üstünden bitir.")
    }

    var showcaseMatchEyebrow: String { t("AI MATCH COACHING", "AI MAÇ KOÇLUĞU") }
    var showcaseMatchHeadline: String {
        t("Log a match — AI tells you exactly what to fix.",
          "Bir maç kaydet — AI tam olarak neyi düzelteceğini söylesin.")
    }
    var showcaseMatchSampleTitle: String { t("Match report · Sample", "Maç raporu · Örnek") }
    var showcaseMatchLine1: String {
        t("You lost the long rallies — your patience dipped after the 5th ball.",
          "Uzun ralileri kaybettin — 5. toptan sonra sabrın düştü.")
    }
    var showcaseMatchLine2: String {
        t("Fix: rally to a target depth before going for the line.",
          "Çözüm: çizgiye gitmeden önce hedef derinliğe oyna.")
    }

    var showcaseDoublesEyebrow: String { t("DOUBLES COMPATIBILITY", "DOUBLES UYUMU") }
    var showcaseDoublesHeadline: String {
        t("See how you and your partner fit — invite them in one tap.",
          "Partnerinle uyumunu gör — tek dokunuşla davet et.")
    }
    var showcaseDoublesScoreLabel: String { t("Compatibility · Sample", "Uyum · Örnek") }
    var showcaseDoublesCaption: String {
        t("Your baseline patience covers their net aggression.",
          "Senin baseline sabrın, onların file agresifliğini tamamlıyor.")
    }

    var showcaseQuizEyebrow: String { t("TENNIS IQ", "TENNIS IQ") }
    var showcaseQuizHeadline: String {
        t("Make the smarter call — daily", "Her gün daha akıllı karar")
    }
    var showcaseScenarioCount: String { t("156 real scenarios", "156 gerçek senaryo") }
    var showcasePathAI: String { t("AI · instant · included", "AI · anında · dahil") }
    var showcasePathCoach: String { t("Real coach · waitlist", "Gerçek antrenör · bekleme listesi") }
    var showcaseQuizSampleTitle: String { t("Today's drill · Sample", "Günün çalışması · Örnek") }
    var showcaseQuizPrompt: String {
        t("Down 30–40 on serve. Where do you go?",
          "Serviste 30–40 gerideysin. Nereye servis atarsın?")
    }
    var showcaseQuizAnswer: String {
        t("Wide to pull them off court — open the court for ball two.",
          "Geniş at, onu sahadan çıkar — ikinci top için sahayı aç.")
    }

    var showcaseCoachEyebrow: String { t("AI COACH", "AI KOÇ") }
    var showcaseCoachHeadline: String {
        t("It knows your game", "Oyununu bilen koç")
    }
    var showcaseCoachSampleTitle: String { t("AI Coach · Sample", "AI Koç · Örnek") }
    // The sample exchange must show what a GENERIC chatbot can't do: answer
    // from YOUR match journal. (ChatGPT would have to ask "who is Alex?")
    var showcaseCoachQuestion: String {
        t("Why do I keep losing to Alex?",
          "Ahmet'e neden sürekli kaybediyorum?")
    }
    var showcaseCoachReply: String {
        t("You've logged 2 losses to Alex — same pattern both times: your serve rating drops in set 2 and you stop going wide. Keep the wide serve in play, and slow things down between points — he wins when he rushes you.",
          "Ahmet'e karşı 2 kayıtlı mağlubiyetin var — ikisinde de aynı desen: 2. sette servis puanın düşüyor ve dışa servisi bırakıyorsun. Dışa servisi oyunda tut, sayılar arasında tempoyu düşür — o, seni acele ettirdiğinde kazanıyor.")
    }

    // Finale slide — honest scale, told big: one floor number that only grows
    // truer as content grows (156 scenarios + 75 drills today), plus outcome
    // lines. No invented user counts or rankings (App Review 2.3.1).
    var showcaseNumbersEyebrow: String { t("Inside DropVolley", "DropVolley'in içinde") }
    var showcaseNumbersHeadline: String {
        t("Built like a coach, not a scoreboard.", "Skor tablosu gibi değil, koç gibi inşa edildi.")
    }
    var numbersHeroLabel: String {
        t("coached scenarios & drills — every one with the why",
          "koçlanmış senaryo ve drill — her biri 'neden'iyle")
    }
    var numbersSwing: String {
        t("Film one swing → a 0–100 score and the exact fix",
          "Tek vuruş çek → 0–100 puan ve tam düzeltme")
    }
    var numbersCoach: String {
        t("Your AI Coach — on call for your game, day and night",
          "AI Koçun — oyunun için gece gündüz hazır")
    }
    var numbersMethod: String {
        t("Grounded in club-level coaching frameworks: NTRP-style levels, real match patterns.",
          "Kulüp seviyesi koçluk çerçevelerine dayalı: NTRP tarzı seviyeler, gerçek maç desenleri.")
    }

    // Early-player quotes — polished from REAL verbal feedback relayed by the
    // owner (match-log AI, programs/drills, swing feedback), anonymous
    // attribution by role+country. No invented users, counts, or ratings.
    var showcaseQuotesEyebrow: String { t("Early players", "İlk oyuncular") }
    var showcaseQuotesHeadline: String { t("What early players say", "İlk oyuncular ne diyor") }
    var quoteMatchLog: String {
        t("I just log my match and the AI tells me what actually went wrong — and what to fix before the next one.",
          "Maçımı giriyorum, AI gerçekte neyin ters gittiğini ve bir sonraki maçtan önce neyi düzelteceğimi söylüyor.")
    }
    var quoteMatchLogWho: String { t("Beginner player, Türkiye", "Başlangıç seviyesi oyuncu, Türkiye") }
    var quotePrograms: String {
        t("The training programs and drills give my week a structure — I always know what to work on next.",
          "Antrenman programları ve driller haftama yapı kazandırdı — sırada ne çalışacağımı hep biliyorum.")
    }
    var quoteProgramsWho: String { t("Club player, Spain", "Kulüp oyuncusu, İspanya") }
    var quoteSwing: String {
        t("The swing feedback surprised me — it caught things about my forehand I'd never noticed.",
          "Vuruş yorumları beni şaşırttı — forehand'imde hiç fark etmediğim şeyleri yakaladı.")
    }
    var quoteSwingWho: String { t("Beginner player, Ireland", "Başlangıç seviyesi oyuncu, İrlanda") }

    var sampleBadge: String { t("Example", "Örnek") }

    // MARK: Bridge into the questionnaire
    var bridgeEyebrow: String { t("NOW THE PERSONAL PART", "ŞİMDİ KİŞİSEL KISIM") }
    var bridgeTitle: String { t("Now let's build YOUR profile.", "Şimdi SENİN profilini oluşturalım.") }

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
    var buildingTitle: String { t("Reading your answers", "Cevapların okunuyor") }
    func buildAnalyzingLevel(_ levelTitle: String) -> String {
        t("Analyzing your level: \(levelTitle)…", "Seviyeni inceliyoruz: \(levelTitle)…")
    }
    func buildMatchingDrills(_ weakness: String) -> String {
        t("Matching scenario drills to your \(weakness)…", "Senaryo çalışmalarını \(weakness) ile eşliyoruz…")
    }
    func buildCalibrating(_ perDay: Int) -> String {
        t("Picking your first scenarios…", "İlk senaryoların seçiliyor…")
    }
    var buildFinalizing: String { t("Finalizing your Tennis Profile…", "Tenis Profilini tamamlıyoruz…") }
    var buildGenericFocus: String { t("game", "oyunun") }

    // MARK: 13 — Result reveal
    var resultReadyKicker: String { t("YOUR TENNIS PROFILE", "TENİS PROFİLİN") }
    func resultPlanLine(goal: String, weakness: String) -> String {
        t("Built from your answers. Here's your first week.",
          "Cevaplarından çıkarıldı. İşte ilk haftan.")
    }
    var firstWeekHeader: String { t("Your first week", "İlk haftan") }
    var firstWeekCoach: String { t("Film one swing and read what the coach sees", "Bir vuruş çek, koçun gördüğünü oku") }
    var firstWeekWall: String { t("Clear the first wall rung: Steady Rally", "İlk duvar basamağını geç: Sabit Rally") }
    var firstWeekTactics: String { t("Lesson 1: Cross-Court Is The Safer Ball", "Ders 1: Çapraz Top Daha Güvenli") }
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
        t("A projection, not a promise — it moves as you train.",
          "Bir tahmin, vaat değil — antrenman ettikçe değişir.")
    }
    var resultContinue: String { t("Let's go", "Hadi başlayalım") }

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
                support: t("Record a quick swing and DropVolley's AI breaks down your technique — grip, contact point, follow-through.",
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
