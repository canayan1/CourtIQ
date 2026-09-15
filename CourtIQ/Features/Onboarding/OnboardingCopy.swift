import Foundation

/// Bilingual copy for the high-conversion onboarding flow (EN/TR). Mirrors the
/// `TennisProfileCopy` pattern: an inline `t(en, tr)` accessor. Spanish falls
/// back to English. Strings here cover only the *new* onboarding screens — the
/// Tennis Profile questions/levels/archetypes are resolved via
/// `TennisProfileCopy`, which this flow reuses.
struct OnboardingCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String, _ fr: String? = nil) -> String {
        switch lang {
        case .turkish: return tr
        case .french:  return fr ?? en
        default:       return en
        }
    }

    // MARK: Navigation
    var next: String { t("Continue", "Devam", "Continuer") }
    var back: String { t("Back", "Geri", "Retour") }
    var getStarted: String { t("Get started", "Başla", "Commencer") }
    var skip: String { t("Skip", "Atla", "Passer") }
    var showcaseContinue: String { t("Continue", "Devam", "Continuer") }

    // MARK: 0 — Hook / positioning (opens the app)
    var hookEyebrow: String { t("DROPVOLLEY", "DROPVOLLEY", "DROPVOLLEY") }
    var hookTitle: String { t("Three ways to get better at tennis.", "Teniste gelişmenin üç yolu.", "Trois façons de progresser au tennis.") }
    var hookSubtitle: String {
        t("Film a swing and get it read. Hit the wall and get it counted. Learn the tactics that win points.", "Vuruşunu çek, okunsun. Duvara vur, sayılsın. Puan kazandıran taktikleri öğren.", "Filme un geste, on te le décrypte. Joue au mur, on te compte. Apprends la tactique qui fait gagner des points.")
    }

    // MARK: Feature showcase — one slide per pillar, each a live sample
    var showcaseCoachPillarEyebrow: String { t("COACH", "KOÇ", "COACH") }
    var showcaseCoachPillarHeadline: String { t("Your swing, reviewed", "Vuruşun, incelenmiş", "Ton geste, analysé") }
    var showcaseWallEyebrow: String { t("WALL", "DUVAR", "MUR") }
    var showcaseWallHeadline: String { t("The wall counts now", "Duvar artık sayıyor", "Le mur compte maintenant") }
    var showcaseWallReps: String { t("reps", "tekrar", "répétitions") }
    var showcaseWallVerdict: String { t("Level cleared", "Seviye geçildi", "Niveau validé") }
    var showcaseWallCaption: String {
        t("Prop the phone behind you. It watches you swing and grades the rung.", "Telefonu arkana koy. Vuruşunu izler, basamağı notlar.", "Pose ton téléphone derrière toi. Il te regarde frapper et note le palier.")
    }
    var showcaseTacticsEyebrow: String { t("TACTICS", "TAKTİK", "TACTIQUE") }
    var showcaseTacticsHeadline: String { t("Learn tactics like a language", "Taktiği bir dil gibi öğren", "Apprends la tactique comme une langue") }
    var showcaseTacticsBubble: String {
        t("Cross-court is the safer ball. Here's why — and when to break the rule.", "Çapraz top daha güvenli. İşte nedeni — ve kuralı ne zaman bozacağın.", "Le croisé est la balle la plus sûre. Voici pourquoi — et quand enfreindre la règle.")
    }
    var showcaseTacticsCaption: String { t("30 lessons · 156 scenarios · chapter 1 free", "30 ders · 156 senaryo · 1. bölüm ücretsiz", "30 leçons · 156 situations · chapitre 1 gratuit") }
    var showcaseJournalEyebrow: String { t("JOURNAL", "GÜNLÜK", "JOURNAL") }
    var showcaseJournalHeadline: String {
        t("Write the season down", "Sezonu yaz", "Écris la saison")
    }
    var showcaseJournalCaption: String {
        t("Matches and fuel in one calendar. Miss a day? Tap it and fill it in.", "Maçlar ve beslenme tek takvimde. Bir günü kaçırdın mı? Dokun ve doldur.", "Matchs et nutrition dans un seul calendrier. Un jour oublié ? Touche-le et remplis-le.")
    }
    var showcaseJournalMatch: String { t("Match", "Maç", "Match") }
    var showcaseJournalFuel: String { t("Fuel", "Beslenme", "Nutrition") }

    var showcaseSwingEyebrow: String { t("SWING", "SWING", "GESTE") }
    var showcaseSwingHeadline: String {
        t("Your swing, two ways", "Vuruşun, iki yol", "Ton geste, deux options")
    }
    var showcaseSwingSampleTitle: String { t("Forehand · Sample", "Forehand · Örnek", "Coup droit · Exemple") }
    var showcaseSwingBullet1: String {
        t("Clean unit turn — shoulders coil early, giving you time to load.", "Temiz gövde dönüşü — omuzlar erken kuruluyor, yüklenmeye zaman tanıyor.", "Belle préparation — les épaules pivotent tôt, tu as le temps de te charger.")
    }
    var showcaseSwingBullet2: String {
        t("Follow-through cuts short — finish over the shoulder for more topspin.", "Bitiriş kısa kalıyor — daha çok topspin için omuz üstünden bitir.", "L'accompagnement est trop court — finis au-dessus de l'épaule pour plus de lift.")
    }

    var showcaseMatchEyebrow: String { t("AI MATCH COACHING", "AI MAÇ KOÇLUĞU", "COACHING DE MATCH PAR IA") }
    var showcaseMatchHeadline: String {
        t("Log a match — AI tells you exactly what to fix.", "Bir maç kaydet — AI tam olarak neyi düzelteceğini söylesin.", "Enregistre un match — l'IA te dit exactement quoi corriger.")
    }
    var showcaseMatchSampleTitle: String { t("Match report · Sample", "Maç raporu · Örnek", "Rapport de match · Exemple") }
    var showcaseMatchLine1: String {
        t("You lost the long rallies — your patience dipped after the 5th ball.", "Uzun ralileri kaybettin — 5. toptan sonra sabrın düştü.", "Tu as perdu les longs échanges — ta patience baisse après la 5e balle.")
    }
    var showcaseMatchLine2: String {
        t("Fix: rally to a target depth before going for the line.", "Çözüm: çizgiye gitmeden önce hedef derinliğe oyna.", "Correction : échange avec une profondeur cible avant de tenter la ligne.")
    }

    var showcaseDoublesEyebrow: String { t("DOUBLES COMPATIBILITY", "DOUBLES UYUMU", "COMPATIBILITÉ EN DOUBLE") }
    var showcaseDoublesHeadline: String {
        t("See how you and your partner fit — invite them in one tap.", "Partnerinle uyumunu gör — tek dokunuşla davet et.", "Vois si ton partenaire et toi êtes complémentaires — invite-le en un tap.")
    }
    var showcaseDoublesScoreLabel: String { t("Compatibility · Sample", "Uyum · Örnek", "Compatibilité · Exemple") }
    var showcaseDoublesCaption: String {
        t("Your baseline patience covers their net aggression.", "Senin baseline sabrın, onların file agresifliğini tamamlıyor.", "Ta patience du fond de court couvre son agressivité au filet.")
    }

    var showcaseQuizEyebrow: String { t("TENNIS IQ", "TENNIS IQ", "QI TENNIS") }
    var showcaseQuizHeadline: String {
        t("Make the smarter call — daily", "Her gün daha akıllı karar", "Fais le bon choix — chaque jour")
    }
    var showcaseScenarioCount: String { t("156 real scenarios", "156 gerçek senaryo", "156 situations réelles") }
    var showcasePathAI: String { t("AI · instant · included", "AI · anında · dahil", "IA · immédiat · inclus") }
    var showcasePathCoach: String { t("Real coach · waitlist", "Gerçek antrenör · bekleme listesi", "Vrai coach · liste d'attente") }
    var showcaseQuizSampleTitle: String { t("Today's drill · Sample", "Günün çalışması · Örnek", "L'exercice du jour · Exemple") }
    var showcaseQuizPrompt: String {
        t("Down 30–40 on serve. Where do you go?", "Serviste 30–40 gerideysin. Nereye servis atarsın?", "30-40 sur ton service. Tu sers où ?")
    }
    var showcaseQuizAnswer: String {
        t("Wide to pull them off court — open the court for ball two.", "Geniş at, onu sahadan çıkar — ikinci top için sahayı aç.", "Extérieur pour le sortir du court — tu ouvres le terrain pour la deuxième balle.")
    }

    var showcaseCoachEyebrow: String { t("AI COACH", "AI KOÇ", "COACH IA") }
    var showcaseCoachHeadline: String {
        t("It knows your game", "Oyununu bilen koç", "Il connaît ton jeu")
    }
    var showcaseCoachSampleTitle: String { t("AI Coach · Sample", "AI Koç · Örnek", "Coach IA · Exemple") }
    // The sample exchange must show what a GENERIC chatbot can't do: answer
    // from YOUR match journal. (ChatGPT would have to ask "who is Alex?")
    var showcaseCoachQuestion: String {
        t("Why do I keep losing to Alex?", "Ahmet'e neden sürekli kaybediyorum?", "Pourquoi je perds toujours contre Alex ?")
    }
    var showcaseCoachReply: String {
        t("You've logged 2 losses to Alex — same pattern both times: your serve rating drops in set 2 and you stop going wide. Keep the wide serve in play, and slow things down between points — he wins when he rushes you.", "Ahmet'e karşı 2 kayıtlı mağlubiyetin var — ikisinde de aynı desen: 2. sette servis puanın düşüyor ve dışa servisi bırakıyorsun. Dışa servisi oyunda tut, sayılar arasında tempoyu düşür — o, seni acele ettirdiğinde kazanıyor.", "Tu as noté 2 défaites contre Alex — même schéma les deux fois : ta note de service chute au 2e set et tu arrêtes de servir extérieur. Garde le service extérieur dans ton jeu, et ralentis entre les points — il gagne quand il te presse.")
    }

    // Finale slide — honest scale, told big: one floor number that only grows
    // truer as content grows (156 scenarios + 75 drills today), plus outcome
    // lines. No invented user counts or rankings (App Review 2.3.1).
    var showcaseNumbersEyebrow: String { t("Inside DropVolley", "DropVolley'in içinde", "Dans DropVolley") }
    var showcaseNumbersHeadline: String {
        t("Built like a coach, not a scoreboard.", "Skor tablosu gibi değil, koç gibi inşa edildi.", "Conçu comme un coach, pas comme un tableau d'affichage.")
    }
    var numbersHeroLabel: String {
        t("coached scenarios & drills — every one with the why", "koçlanmış senaryo ve drill — her biri 'neden'iyle", "situations et exercices coachés — chacun avec le pourquoi")
    }
    var numbersSwing: String {
        t("Film one swing → a 0–100 score and the exact fix", "Tek vuruş çek → 0–100 puan ve tam düzeltme", "Filme un geste → une note sur 100 et la correction précise")
    }
    var numbersCoach: String {
        t("Your AI Coach — on call for your game, day and night", "AI Koçun — oyunun için gece gündüz hazır", "Ton Coach IA — disponible pour ton jeu, jour et nuit")
    }
    var numbersMethod: String {
        t("Grounded in club-level coaching frameworks: NTRP-style levels, real match patterns.", "Kulüp seviyesi koçluk çerçevelerine dayalı: NTRP tarzı seviyeler, gerçek maç desenleri.", "Fondé sur des référentiels d'entraînement de niveau club : niveaux de type NTRP, schémas de match réels.")
    }

    // Early-player quotes — polished from REAL verbal feedback relayed by the
    // owner (match-log AI, programs/drills, swing feedback), anonymous
    // attribution by role+country. No invented users, counts, or ratings.
    var showcaseQuotesEyebrow: String { t("Early players", "İlk oyuncular", "Premiers joueurs") }
    var showcaseQuotesHeadline: String { t("What early players say", "İlk oyuncular ne diyor", "Ce que disent les premiers joueurs") }
    var quoteMatchLog: String {
        t("I just log my match and the AI tells me what actually went wrong — and what to fix before the next one.", "Maçımı giriyorum, AI gerçekte neyin ters gittiğini ve bir sonraki maçtan önce neyi düzelteceğimi söylüyor.", "J'enregistre simplement mon match et l'IA me dit ce qui a vraiment coincé — et quoi corriger avant le suivant.")
    }
    var quoteMatchLogWho: String { t("Beginner player, Türkiye", "Başlangıç seviyesi oyuncu, Türkiye", "Joueur débutant, Turquie") }
    var quotePrograms: String {
        t("The training programs and drills give my week a structure — I always know what to work on next.", "Antrenman programları ve driller haftama yapı kazandırdı — sırada ne çalışacağımı hep biliyorum.", "Les programmes et les exercices structurent ma semaine — je sais toujours quoi travailler ensuite.")
    }
    var quoteProgramsWho: String { t("Club player, Spain", "Kulüp oyuncusu, İspanya", "Joueur de club, Espagne") }
    var quoteSwing: String {
        t("The swing feedback surprised me — it caught things about my forehand I'd never noticed.", "Vuruş yorumları beni şaşırttı — forehand'imde hiç fark etmediğim şeyleri yakaladı.", "Le retour sur mon geste m'a surpris — il a repéré des choses sur mon coup droit que je n'avais jamais vues.")
    }
    var quoteSwingWho: String { t("Beginner player, Ireland", "Başlangıç seviyesi oyuncu, İrlanda", "Joueur débutant, Irlande") }

    var sampleBadge: String { t("Example", "Örnek", "Exemple") }

    // MARK: Bridge into the questionnaire
    var bridgeEyebrow: String { t("NOW THE PERSONAL PART", "ŞİMDİ KİŞİSEL KISIM", "MAINTENANT, LE PERSONNEL") }
    var bridgeTitle: String { t("Now let's build YOUR profile.", "Şimdi SENİN profilini oluşturalım.", "Construisons maintenant TON profil.") }

    // MARK: 1 — Welcome / hook
    var welcomeTitle: String {
        t("Train the tennis brain that wins matches", "Maç kazandıran tenis beynini eğit", "Entraîne le cerveau tennis qui gagne les matchs")
    }
    var welcomeBullets: [String] {
        [
            t("Real match scenarios, not just stroke tips", "Sadece vuruş ipuçları değil — gerçek maç senaryoları", "De vraies situations de match, pas juste des conseils techniques"),
            t("A coach that learns your game and remembers it", "Oyununu öğrenen ve hatırlayan bir koç", "Un coach qui apprend ton jeu et s'en souvient"),
            t("Build true Tennis IQ — the decisions that win points", "Gerçek Tenis IQ'su geliştir — puan kazandıran kararlar", "Développe un vrai QI tennis — les décisions qui gagnent les points"),
        ]
    }

    // MARK: 2 — Goal
    var goalQuestion: String { t("What's your #1 tennis goal?", "Bir numaralı tenis hedefin ne?", "Quel est ton objectif tennis numéro 1 ?") }
    func goalOption(_ g: OnboardingGoal) -> String {
        switch g {
        case .winMatches:   return t("Win more matches", "Daha çok maç kazanmak", "Gagner plus de matchs")
        case .fixWeakness:  return t("Fix specific weaknesses", "Belirli zayıflıkları gidermek", "Corriger des faiblesses précises")
        case .strategy:     return t("Understand strategy & tactics", "Strateji ve taktiği anlamak", "Comprendre la stratégie et la tactique")
        case .climbLevel:   return t("Climb my level (NTRP)", "Seviye atlamak (NTRP)", "Monter de niveau (NTRP)")
        }
    }

    // MARK: 8 — Weaknesses (pain points, multi-select)
    var weaknessQuestion: String { t("Where do you lose points?", "Puanları nerede kaybediyorsun?", "Où perds-tu tes points ?") }
    var weaknessHint: String { t("Pick all that apply.", "Geçerli olanların hepsini seç.", "Choisis tout ce qui s'applique.") }
    func weaknessOption(_ w: OnboardingWeakness) -> String {
        switch w {
        case .backhand:      return t("Backhand", "Backhand", "Revers")
        case .serve:         return t("Serve", "Servis", "Service")
        case .netPlay:       return t("Net play", "File oyunu", "Jeu au filet")
        case .ret:           return t("Return", "Return", "Retour")
        case .shotSelection: return t("Shot selection", "Vuruş seçimi", "Choix des coups")
        case .mentalGame:    return t("Mental game", "Zihinsel oyun", "Mental")
        case .fitness:       return t("Fitness", "Kondisyon", "Condition physique")
        }
    }

    // MARK: 9 — Behavioral sliders (two-statement, Noom-style)
    var slidersTitle: String { t("How do you play the big points?", "Önemli puanları nasıl oynarsın?", "Comment joues-tu les points importants ?") }
    var slidersIntro: String { t("Drag toward the statement that fits you.", "Sana uyan ifadeye doğru kaydır.", "Fais glisser vers la phrase qui te correspond.") }

    var sliderPatienceLeft: String { t("I rush big points", "Önemli puanlarda acele ederim", "Je précipite les points importants") }
    var sliderPatienceRight: String { t("I stay patient", "Sabırlı kalırım", "Je reste patient") }

    var sliderTacticsLeft: String { t("I just react", "Sadece tepki veririm", "Je réagis, c'est tout") }
    var sliderTacticsRight: String { t("I play tactically", "Taktiksel oynarım", "Je joue tactique") }

    var sliderAggressionLeft: String { t("I play it safe", "Garantiye oynarım", "Je joue la sécurité") }
    var sliderAggressionRight: String { t("I go for my shots", "Vuruşlarımı denerim", "Je tente mes coups") }

    // MARK: 11 — Commitment
    var commitmentQuestion: String { t("How many scenario drills a day?", "Günde kaç senaryo çalışması?", "Combien de situations par jour ?") }
    func commitmentFeedback(_ perDay: Int) -> String {
        let monthly = perDay * 30
        return t("\(perDay)/day → ~\(monthly) scenarios this month", "Günde \(perDay) → bu ay ~\(monthly) senaryo", "\(perDay)/jour → ~\(monthly) situations ce mois-ci")
    }
    func perDayLabel(_ perDay: Int) -> String {
        t("\(perDay)/day", "Günde \(perDay)", "\(perDay)/jour")
    }

    // MARK: 12 — Labor illusion (building plan)
    var buildingTitle: String { t("Reading your answers", "Cevapların okunuyor", "Lecture de tes réponses") }
    func buildAnalyzingLevel(_ levelTitle: String) -> String {
        t("Analyzing your level: \(levelTitle)…", "Seviyeni inceliyoruz: \(levelTitle)…", "Analyse de ton niveau : \(levelTitle)…")
    }
    func buildMatchingDrills(_ weakness: String) -> String {
        t("Matching scenario drills to your \(weakness)…", "Senaryo çalışmalarını \(weakness) ile eşliyoruz…", "Sélection des situations pour travailler : \(weakness)…")
    }
    func buildCalibrating(_ perDay: Int) -> String {
        t("Picking your first scenarios…", "İlk senaryoların seçiliyor…", "Sélection de tes premières situations…")
    }
    var buildFinalizing: String { t("Finalizing your Tennis Profile…", "Tenis Profilini tamamlıyoruz…", "Finalisation de ton profil tennis…") }
    var buildGenericFocus: String { t("game", "oyunun", "jeu") }

    // MARK: 13 — Result reveal
    var resultReadyKicker: String { t("YOUR TENNIS PROFILE", "TENİS PROFİLİN", "TON PROFIL TENNIS") }
    func resultPlanLine(goal: String, weakness: String) -> String {
        t("Built from your answers. Here's your first week.", "Cevaplarından çıkarıldı. İşte ilk haftan.", "Construit à partir de tes réponses. Voici ta première semaine.")
    }
    var firstWeekHeader: String { t("Your first week", "İlk haftan", "Ta première semaine") }
    var firstWeekCoach: String { t("Film one swing and read what the coach sees", "Bir vuruş çek, koçun gördüğünü oku", "Filme un geste et lis ce que le coach voit") }
    var firstWeekWall: String { t("Clear the first wall rung: Steady Rally", "İlk duvar basamağını geç: Sabit Rally", "Valide le premier palier du mur : Steady Rally") }
    var firstWeekTactics: String { t("Lesson 1: Cross-Court Is The Safer Ball", "Ders 1: Çapraz Top Daha Güvenli", "Leçon 1 : le croisé est la balle la plus sûre") }
    func resultGoalPhrase(_ g: OnboardingGoal) -> String {
        switch g {
        case .winMatches:  return t("win more matches", "daha çok maç kazanman", "gagner plus de matchs")
        case .fixWeakness: return t("close your gaps", "açıklarını kapatman", "combler tes lacunes")
        case .strategy:    return t("master strategy", "stratejiyi öğrenmen", "maîtriser la stratégie")
        case .climbLevel:  return t("climb your level", "seviye atlaman", "monter de niveau")
        }
    }
    var tennisIQHeader: String { t("Your Tennis IQ", "Tenis IQ'n", "Ton QI tennis") }
    var iqToday: String { t("Today", "Bugün", "Aujourd'hui") }
    func iqTarget(_ timeframe: String) -> String { t("In \(timeframe)", "\(timeframe) içinde", "Dans \(timeframe)") }
    var iqTimeframe: String { t("8 weeks", "8 hafta", "8 semaines") }
    var iqProjectionNote: String {
        t("A projection, not a promise — it moves as you train.", "Bir tahmin, vaat değil — antrenman ettikçe değişir.", "Une projection, pas une promesse — elle bouge avec ton travail.")
    }
    var resultContinue: String { t("Let's go", "Hadi başlayalım", "C'est parti") }

    // MARK: Result section headers (reused alongside TennisProfileCopy)
    var levelHeader: String { t("Your level", "Seviyen", "Ton niveau") }
    var styleHeader: String { t("Your style", "Stilin", "Ton style") }
    var strengthsHeader: String { t("Your strengths", "Güçlü yönlerin", "Tes points forts") }
    var growthHeader: String { t("Grow these next", "Sıradaki gelişim", "À développer ensuite") }

    // MARK: 14 — Leave a review
    var reviewTitle: String { t("Loving your plan?", "Planını sevdin mi?", "Ton plan te plaît ?") }
    var reviewBody: String {
        t("A quick review helps DropVolley grow — and helps other players find it. 🎾", "Kısa bir değerlendirme DropVolley'in büyümesine — ve başka oyuncuların bulmasına — çok yardımcı olur. 🎾", "Un avis rapide aide DropVolley à grandir — et aide d'autres joueurs à le découvrir. 🎾")
    }
    var reviewRate: String { t("Rate DropVolley", "DropVolley'i değerlendir", "Noter DropVolley") }
    var reviewLater: String { t("Maybe later", "Belki sonra", "Plus tard") }

    // MARK: 15 — Evidence carousel ("why DropVolley is different")
    struct EvidenceSlide { let headline: String; let support: String; let symbol: String }
    var evidenceSlides: [EvidenceSlide] {
        [
            EvidenceSlide(
                headline: t("See your swing like a coach does", "Vuruşunu bir koç gibi gör", "Vois ton geste comme un coach le voit"),
                support: t("Record a quick swing and DropVolley's AI breaks down your technique — grip, contact point, follow-through.", "Kısa bir vuruş çek; DropVolley'in AI'ı tekniğini çözümlesin — grip, temas noktası, takip.", "Filme un geste rapide et l'IA de DropVolley décortique ta technique — prise, point d'impact, accompagnement."),
                symbol: "video.fill"
            ),
            EvidenceSlide(
                headline: t("Other apps fix your strokes.\nDropVolley fixes your decisions.", "Diğer uygulamalar vuruşunu düzeltir.\nDropVolley kararlarını düzeltir.", "Les autres apps corrigent tes coups.\nDropVolley corrige tes décisions."),
                support: t("Matches are won between the ears — by the shot you choose, not just the one you hit.", "Maçlar kafada kazanılır — vurduğun değil, seçtiğin vuruşla.", "Les matchs se gagnent entre les deux oreilles — par le coup que tu choisis, pas seulement par celui que tu frappes."),
                symbol: "brain.head.profile"
            ),
            EvidenceSlide(
                headline: t("A coach that remembers\nevery match.", "Her maçı hatırlayan\nbir koç.", "Un coach qui se souvient\nde chaque match."),
                support: t("Your AI Coach knows your level, your style, and your last result — and coaches from it.", "AI Koç'un seviyeni, stilini ve son skorunu bilir — ona göre yönlendirir.", "Ton Coach IA connaît ton niveau, ton style et ton dernier résultat — et il coache à partir de ça."),
                symbol: "brain.head.profile"
            ),
            EvidenceSlide(
                headline: t("Know your real game —\nnot just a rating.", "Gerçek oyununu bil —\nsadece bir puanı değil.", "Connais ton vrai jeu —\npas juste un classement."),
                support: t("Your Tennis Profile shows exactly where you stand and what to work on next.", "Tenis Profilin tam olarak nerede olduğunu ve sıradaki adımı gösterir.", "Ton profil tennis montre exactement où tu en es et quoi travailler ensuite."),
                symbol: "chart.bar.fill"
            ),
        ]
    }
    var seeMyPlan: String { t("See my plan", "Planımı gör", "Voir mon plan") }
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
