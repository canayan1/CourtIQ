import Foundation

/// Bilingual copy for the Tennis Profile feature (EN/TR). Self-contained,
/// mirrors the DoublesCopy pattern. Spanish falls back to English.
struct TennisProfileCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String) -> String { lang == .turkish ? tr : en }

    // MARK: Section / entry
    var sectionTitle: String { t("Tennis Profile", "Tenis Profili") }
    var entryTitle: String { t("Discover your tennis profile", "Tenis profilini keşfet") }
    var entrySubtitle: String {
        t("Answer 12 quick questions to see your level, your style, and what to work on next.",
          "12 hızlı soruyla seviyeni, stilini ve sıradaki gelişim alanını gör.")
    }
    var startCTA: String { t("Start the test", "Teste başla") }
    var retakeCTA: String { t("Retake the test", "Testi yeniden yap") }
    var next: String { t("Next", "İleri") }
    var back: String { t("Back", "Geri") }
    var seeProfile: String { t("See my profile", "Profilimi gör") }

    // MARK: Disclaimer (self-rating is provisional)
    var provisionalNote: String {
        t("This is a self-assessment, so treat it as a starting point — most players slightly under-rate themselves. When unsure, pick the higher option.",
          "Bu bir öz-değerlendirme; başlangıç noktası olarak gör — çoğu oyuncu kendini biraz düşük puanlar. Emin değilsen yükseğini seç.")
    }

    // MARK: Dimensions
    func dimension(_ d: TennisDimension) -> String {
        switch d {
        case .forehand: return t("Forehand", "Forehand")
        case .backhand: return t("Backhand", "Backhand")
        case .serve:    return t("Serve", "Servis")
        case .ret:      return t("Return", "Return")
        case .net:      return t("Net play / volleys", "File oyunu / vole")
        case .movement: return t("Movement & footwork", "Hareket & ayak işi")
        }
    }
    var scaleWeak: String { t("Shaky", "Zayıf") }
    var scaleStrong: String { t("A weapon", "Silahım") }

    // MARK: Levels
    func levelTitle(_ l: TennisLevel) -> String {
        switch l {
        case .new:          return t("New to tennis", "Tenise yeni")
        case .improver:     return t("Improver", "Gelişen")
        case .intermediate: return t("Intermediate", "Orta seviye")
        case .solidClub:    return t("Solid club player", "Sağlam kulüp oyuncusu")
        case .advancedClub: return t("Advanced club player", "İleri kulüp oyuncusu")
        }
    }
    func levelNTRP(_ l: TennisLevel) -> String {
        switch l {
        case .new:          return "NTRP ~1.5–2.0"
        case .improver:     return "NTRP ~2.5"
        case .intermediate: return "NTRP ~3.0"
        case .solidClub:    return "NTRP ~3.5"
        case .advancedClub: return "NTRP ~4.0+"
        }
    }
    func levelBlurb(_ l: TennisLevel) -> String {
        switch l {
        case .new:          return t("You're learning the strokes and getting the ball in play. Every session builds the base.", "Vuruşları öğreniyor ve topu oyunda tutuyorsun. Her antrenman temeli kuruyor.")
        case .improver:     return t("You can keep a slow rally going; matches are coming together but still inconsistent.", "Yavaş bir ralliyi sürdürebiliyorsun; maçlar oturuyor ama hâlâ değişken.")
        case .intermediate: return t("You rally with medium pace fairly consistently — now it's about control and depth.", "Orta tempoyla istikrarlı rally yapıyorsun — şimdi kontrol ve derinlik zamanı.")
        case .solidClub:    return t("Dependable strokes, you direct the ball, use lobs, and come to the net.", "Güvenilir vuruşlar; topu yönlendiriyor, lob kullanıyor ve fileye geliyorsun.")
        case .advancedClub: return t("Reliable shots with depth and control, and you're adding pace and spin.", "Derinlik ve kontrollü güvenilir vuruşlar; tempo ve spin de ekliyorsun.")
        }
    }

    // MARK: Archetypes
    func archetypeTitle(_ a: TennisArchetype) -> String {
        switch a {
        case .developing:         return t("Developing player", "Gelişen oyuncu")
        case .aggressiveBaseliner:return t("Aggressive baseliner", "Agresif baseliner")
        case .counterpuncher:     return t("Counterpuncher", "Counterpuncher")
        case .allCourt:           return t("All-court player", "All-court oyuncu")
        case .serveVolleyer:      return t("Serve-and-volleyer", "Serve-and-volley")
        }
    }
    func archetypeBlurb(_ a: TennisArchetype) -> String {
        switch a {
        case .developing:          return t("You're building the fundamentals across the board. Pick one or two areas and stack reps.", "Temelleri baştan kuruyorsun. Bir-iki alan seç ve tekrar üstüne tekrar koy.")
        case .aggressiveBaseliner: return t("You dictate from the back of the court with your groundstrokes — control + depth turn that into wins.", "Kort arkasından groundstroke'larınla oyunu yönetiyorsun — kontrol + derinlik bunu galibiyete çevirir.")
        case .counterpuncher:      return t("You move well and outlast opponents with steady, smart balls. Add a way to finish points.", "İyi hareket ediyor, istikrarlı ve akıllı toplarla rakibi yoruyorsun. Puan bitirme yolu ekle.")
        case .allCourt:            return t("You're comfortable everywhere — baseline and net. Use that range to take time away.", "Her yerde rahatsın — baseline ve file. Bu çok yönlülüğü rakibin zamanını çalmak için kullan.")
        case .serveVolleyer:       return t("Your serve and net game set the tone. Sharpen the first volley and the approach.", "Servisin ve file oyunun tempoyu belirliyor. İlk voleyi ve file alışını keskinleştir.")
        }
    }

    // MARK: Result labels
    var levelHeader: String { t("Your level", "Seviyen") }
    var styleHeader: String { t("Your style", "Stilin") }
    var strengthsHeader: String { t("Your strengths", "Güçlü yönlerin") }
    var growthHeader: String { t("Grow these next", "Sıradaki gelişim") }
    var goalsHeader: String { t("Suggested goals", "Önerilen hedefler") }
    var goalsSubhead: String { t("Pick the goals you want to chase — your Coach will help.", "Takip etmek istediğin hedefleri seç — Koç'un yardımcı olur.") }
    var adoptGoals: String { t("Save my goals", "Hedeflerimi kaydet") }
    var aiTeaser: String { t("Your AI Coach now knows your profile and goals — and will coach you toward them.", "AI Koç'un artık profilini ve hedeflerini biliyor — ve seni onlara doğru yönlendirir.") }
    var myGoalsHeader: String { t("Your goals", "Hedeflerin") }

    // MARK: Goals (coaching-standard development priorities)
    func goalTitle(_ key: String) -> String {
        switch key {
        case "goal.serve.title":       return t("Build a reliable second serve", "Güvenilir bir ikinci servis kur")
        case "goal.return.title":      return t("Get more returns deep and in play", "Daha çok return'ü derin ve oyunda tut")
        case "goal.forehand.title":    return t("Make the forehand a steady weapon", "Forehand'i istikrarlı bir silaha çevir")
        case "goal.backhand.title":    return t("Make the backhand dependable", "Backhand'i güvenilir kıl")
        case "goal.net.title":         return t("Finish points at the net", "Puanları filede bitir")
        case "goal.movement.title":    return t("Move and recover better", "Daha iyi hareket et ve toparlan")
        case "goal.compete.title":     return t("Win more of your matches", "Maçlarının daha çoğunu kazan")
        case "goal.technique.title":   return t("Sharpen your technique", "Tekniğini keskinleştir")
        case "goal.fitness.title":     return t("Build tennis fitness", "Tenis kondisyonu geliştir")
        case "goal.consistency.title": return t("Cut your unforced errors", "Zorlanmamış hataları azalt")
        case "goal.fun.title":         return t("Play more and enjoy it", "Daha çok oyna ve keyfini çıkar")
        default: return key
        }
    }
    func goalDetail(_ key: String) -> String {
        switch key {
        case "goal.serve.detail":       return t("Aim for ~75% second serves in with a little spin — a steady second serve removes free points.", "Hafif spinle ikinci servislerin ~%75'ini içeri at — sağlam ikinci servis bedava puanları keser.")
        case "goal.return.detail":      return t("Just get it back deep and crosscourt — a return in play starts the point on your terms.", "Sadece derin ve çapraz geri koy — oyunda kalan return puanı senin şartlarında başlatır.")
        case "goal.forehand.detail":    return t("Rally 10 crosscourt forehands in a row with topspin for margin.", "Marj için topspinle 10 çapraz forehand'i üst üste rally yap.")
        case "goal.backhand.detail":    return t("Make it a dependable rally ball; a reliable slice keeps you in points.", "Onu güvenilir bir rally topu yap; sağlam bir slice seni puanda tutar.")
        case "goal.net.detail":         return t("Close the net on short balls and put away the first volley.", "Kısa toplarda fileyi kapat ve ilk voleyi bitir.")
        case "goal.movement.detail":    return t("Split-step on every opponent contact and recover to the middle after each shot.", "Rakip her vuruşta split-step yap ve her vuruştan sonra ortaya toparlan.")
        case "goal.compete.detail":     return t("Log your matches and review what wins and loses points for you.", "Maçlarını logla ve sana puan kazandıran/kaybettiren şeyleri gözden geçir.")
        case "goal.technique.detail":   return t("Pick one stroke and drill it with focus each session.", "Bir vuruş seç ve her antrenmanda bilinçli çalış.")
        case "goal.fitness.detail":     return t("Follow a training block so you're still moving well late in matches.", "Bir antrenman bloğu uygula ki maç sonunda hâlâ iyi hareket edesin.")
        case "goal.consistency.detail": return t("Target rallies of 10+ balls before you go for a winner.", "Vinner denemeden önce 10+ toplu ralliler hedefle.")
        case "goal.fun.detail":         return t("Keep a simple streak going — consistency beats intensity.", "Basit bir seri tut — istikrar yoğunluğu yener.")
        default: return key
        }
    }

    // MARK: Questionnaire prompts
    var qExperience: String { t("How long have you played tennis?", "Ne kadar süredir tenis oynuyorsun?") }
    var qFrequency: String { t("How often do you play now?", "Şu an ne sıklıkla oynuyorsun?") }
    var qMatch: String { t("Do you play matches?", "Maç oynuyor musun?") }
    var qLevel: String { t("Which best describes your game right now?", "Oyununu şu an en iyi hangisi anlatır?") }
    var qStrokesHeader: String { t("Rate your shots", "Vuruşlarını puanla") }
    var qStrokesIntro: String { t("1 = shaky, 5 = a weapon you trust.", "1 = zayıf, 5 = güvendiğin bir silah.") }
    var qPressure: String { t("In a tight game, you usually…", "Çekişmeli bir oyunda genelde…") }
    var qWant: String { t("What do you want most from tennis right now?", "Tenisten şu an en çok ne istiyorsun?") }

    func experienceOption(_ v: TennisExperience) -> String {
        switch v {
        case .justStarting:    return t("Just starting (weeks / first lessons)", "Yeni başladım (haftalar / ilk dersler)")
        case .underOneYear:    return t("Under a year", "Bir yıldan az")
        case .oneToThreeYears: return t("1–3 years", "1–3 yıl")
        case .threeToTenYears: return t("3–10 years", "3–10 yıl")
        case .tenPlusYears:    return t("10+ years", "10+ yıl")
        }
    }
    func frequencyOption(_ v: PlayFrequency) -> String {
        switch v {
        case .rarely:      return t("A few times a year", "Yılda birkaç kez")
        case .monthly:     return t("About monthly", "Ayda bir civarı")
        case .weekly:      return t("Weekly", "Haftada bir")
        case .twiceThrice: return t("2–3× a week", "Haftada 2–3")
        case .fourPlus:    return t("4+ a week", "Haftada 4+")
        }
    }
    func matchOption(_ v: MatchExperience) -> String {
        switch v {
        case .never:         return t("No — just hitting", "Hayır — sadece vuruyorum")
        case .socialHits:    return t("Casual hits, a few points", "Rahat vuruşlar, birkaç puan")
        case .casualMatches: return t("Friendly matches", "Dostluk maçları")
        case .leagueMatches: return t("Club / league matches", "Kulüp / lig maçları")
        case .tournaments:   return t("Tournaments", "Turnuvalar")
        }
    }
    func levelOption(_ v: LevelSelfPlacement) -> String {
        switch v {
        case .learningBasics:     return t("Still learning the basics — getting the ball in play", "Hâlâ temelleri öğreniyorum — topu oyunda tutmak")
        case .keepRallyGoing:     return t("I can keep a slow rally going, but matches are inconsistent", "Yavaş ralliyi sürdürebilirim ama maçlar değişken")
        case .consistentMedium:   return t("I rally at medium pace fairly consistently, but lack control/depth", "Orta tempoda epey istikrarlı rally yaparım ama kontrol/derinlik eksik")
        case .dependableDirected: return t("Dependable strokes — I direct the ball, use lobs, come to the net", "Güvenilir vuruşlar — topu yönlendirir, lob kullanır, fileye gelirim")
        case .depthControlSpin:   return t("Reliable with depth and control, and some pace/spin", "Derinlik ve kontrollü güvenilir; biraz tempo/spin")
        }
    }
    func pressureOption(_ v: PressureResponse) -> String {
        switch v {
        case .rushErrors:  return t("Rush and make errors", "Acele edip hata yaparım")
        case .playSafe:    return t("Get safe and just keep it in", "Garantiye alıp sadece içeride tutarım")
        case .patientPick: return t("Stay patient and pick my moment", "Sabırlı kalıp anımı kollarım")
        case .goForIt:     return t("Back myself and go for it", "Kendime güvenip giderim")
        }
    }
    func wantOption(_ v: TennisWant) -> String {
        switch v {
        case .compete:     return t("Compete and win more", "Rekabet & daha çok kazanmak")
        case .technique:   return t("Sharper technique", "Daha iyi teknik")
        case .fitness:     return t("Get fitter / move better", "Daha fit / daha iyi hareket")
        case .consistency: return t("Be more consistent", "Daha istikrarlı olmak")
        case .fun:         return t("Have fun / play more", "Keyif / daha çok oynamak")
        }
    }
}
