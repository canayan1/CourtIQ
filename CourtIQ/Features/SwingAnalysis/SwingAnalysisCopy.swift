import Foundation

/// Bilingual copy for the AI Swing Analysis feature (EN/TR). Self-contained,
/// mirrors the TennisProfileCopy pattern. Spanish falls back to English.
struct SwingAnalysisCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String) -> String { lang == .turkish ? tr : en }

    // MARK: Feature title / nav
    var title: String { t("Swing Analysis", "Vuruş Analizi") }
    var navTitle: String { t("AI Swing Analysis", "AI Vuruş Analizi") }

    // MARK: Step 1 — stroke + handedness
    var step1Kicker: String { t("Step 1 of 2", "Adım 1 / 2") }
    var pickStrokeTitle: String { t("What stroke are you filming?", "Hangi vuruşu çekiyorsun?") }
    var pickHandednessTitle: String { t("Which hand do you play with?", "Hangi elinle oynuyorsun?") }

    func stroke(_ s: SwingStroke) -> String {
        switch s {
        case .forehand: return t("Forehand", "Forehand")
        case .backhand: return t("Backhand", "Backhand")
        case .serve:    return t("Serve", "Servis")
        case .volley:   return t("Volley", "Vole")
        }
    }

    func handedness(_ h: SwingHandedness) -> String {
        switch h {
        case .right: return t("Right-handed", "Sağ elli")
        case .left:  return t("Left-handed", "Sol elli")
        }
    }

    var filmingTipTitle: String { t("How to film", "Nasıl çekilir") }
    var filmingTipBody: String {
        t("Film from the side, 10–15 seconds, with your full body in frame.",
          "Yandan çek, 10–15 saniye, tüm vücudun karede olsun.")
    }
    var continueCTA: String { t("Continue", "Devam") }

    // MARK: Step 2 — capture
    var step2Kicker: String { t("Step 2 of 2", "Adım 2 / 2") }
    var captureTitle: String { t("Add your swing video", "Vuruş videonu ekle") }
    var captureSubtitle: String {
        t("Record a new clip or choose one from your library. Keep it short — about 10–15 seconds.",
          "Yeni bir klip çek ya da galerinden seç. Kısa tut — yaklaşık 10–15 saniye.")
    }
    var recordCTA: String { t("Record a swing", "Vuruş çek") }
    var libraryCTA: String { t("Choose from library", "Galeriden seç") }
    var backCTA: String { t("Back", "Geri") }

    // MARK: Loading
    func analyzingStroke(_ s: SwingStroke) -> String {
        switch lang {
        case .turkish: return "\(stroke(s)) analiz ediliyor…"
        default:       return "Analyzing your \(stroke(s).lowercased())…"
        }
    }
    var analyzingSubtitle: String {
        t("Reading the frames and writing your coaching notes.",
          "Kareler okunuyor ve koçluk notların yazılıyor.")
    }

    // MARK: Result
    var resultTitle: String { t("Your coaching notes", "Koçluk notların") }
    var analyzeAnotherCTA: String { t("Analyze another", "Bir tane daha analiz et") }

    // MARK: Errors
    var errorTitle: String { t("Something went wrong", "Bir şeyler ters gitti") }
    var errorGeneric: String {
        t("We couldn't analyze that clip. Please try again.",
          "Bu klibi analiz edemedik. Lütfen tekrar dene.")
    }
    var errorTooShort: String {
        t("That clip was too short or unreadable. Try a 10–15 second video.",
          "Bu klip çok kısa ya da okunamadı. 10–15 saniyelik bir video dene.")
    }
    var errorConnect: String {
        t("We couldn't reach the analysis service. Check your connection and try again.",
          "Analiz servisine ulaşamadık. Bağlantını kontrol edip tekrar dene.")
    }
    var retryCTA: String { t("Retry", "Tekrar dene") }
    var cancelCTA: String { t("Cancel", "Vazgeç") }
}
