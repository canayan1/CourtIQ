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
    var pickStrokeTitle: String { t("What do you want analyzed?", "Neyi analiz edelim?") }
    var pickHandednessTitle: String { t("Which hand do you play with?", "Hangi elinle oynuyorsun?") }

    func stroke(_ s: SwingStroke) -> String {
        switch s {
        case .forehand: return t("Forehand", "Forehand")
        case .backhand: return t("Backhand", "Backhand")
        case .serve:    return t("Serve", "Servis")
        case .volley:   return t("Volley", "Vole")
        case .session:  return t("Whole session (mixed strokes)", "Tüm seans (karışık vuruşlar)")
        case .footwork: return t("Footwork & movement", "Footwork & hareket")
        }
    }

    func handedness(_ h: SwingHandedness) -> String {
        switch h {
        case .right: return t("Right-handed", "Sağ elli")
        case .left:  return t("Left-handed", "Sol elli")
        }
    }

    var filmingTipTitle: String { t("How to film", "Nasıl çekilir") }
    func filmingTipBody(_ s: SwingStroke) -> String {
        if s.isFootwork {
            return t("Film from behind or wide from the side, full body and the court around you in frame. Move and hit a few balls so your footwork is visible — good even light, steady phone.",
                     "Arkadan ya da yandan geniş çek — tüm vücudun ve etrafındaki kort karede. Birkaç top oyna ki ayak işin görünsün. İyi ışık, sabit telefon.")
        }
        if s.isSession {
            return t("Film your whole hit — serves, forehands, backhands together. Side view, full body in frame, good even light. The AI identifies each stroke and breaks it down separately.",
                     "Tüm antrenmanını çek — servis, forehand, backhand bir arada. Yandan, tüm vücut karede, iyi ışık. AI her vuruşu tanıyıp ayrı ayrı çözümler.")
        }
        // Canonical capture angle = FROM BEHIND (SwingVision-style: behind the
        // player, slightly high, whole body centred). Matches the calibration
        // of our on-device counting + pose pipeline; consistency beats any
        // single "ideal" angle. Framing warning is load-bearing: pose-empty
        // clips were 1/3 of our first training set.
        return t("Film from BEHIND with the phone slightly high (lean it on the fence), your whole body centred in frame. Hit several reps of the same stroke — 10–30 seconds is ideal. Repeated swings let the AI spot the faults that recur; if you drift out of frame, those swings can't be read.",
                 "ARKADAN çek, telefon hafif yüksekte (çite yasla), tüm vücudun kadrajın ORTASINDA. Aynı vuruştan birkaç tekrar yap — ideali 10–30 saniye. Tekrarlar AI'ın tekrar eden hataları yakalamasını sağlar; kadraj dışına taşarsan o vuruşlar okunamaz.")
    }
    var continueCTA: String { t("Continue", "Devam") }

    // MARK: Step 2 — capture
    var step2Kicker: String { t("Step 2 of 2", "Adım 2 / 2") }
    var captureTitle: String { t("Add your swing video", "Vuruş videonu ekle") }
    var captureSubtitle: String {
        t("Record a new clip or choose one from your library.",
          "Yeni bir klip çek ya da galerinden seç.")
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
    /// K2 transitional honesty: score is the model's estimate until the R2
    /// measured rubric lands.
    var scoreBasisBadge: String { t("AI estimate", "AI tahmini") }
    var mismatchNotice: String {
        t("The strokes in this clip don't look like the type you picked, so there's no coaching below — just what the AI actually saw. Re-check the stroke and try again.",
          "Bu klipteki vuruşlar seçtiğin tiple uyuşmuyor — aşağıda koçluk değil, AI'ın gerçekte ne gördüğü yazıyor. Vuruş tipini kontrol edip tekrar dene.")
    }
    func measuredCountChip(_ n: Int) -> String {
        t("\(n) strike\(n == 1 ? "" : "s") measured on device",
          "cihazda \(n) vuruş ölçüldü")
    }
    func measuredOverheadChip(_ pct: Int) -> String {
        t("\(pct)% overhead", "%\(pct) başüstü")
    }
    var analyzeAnotherCTA: String { t("Analyze another", "Bir tane daha analiz et") }

    // MARK: Score
    /// Label shown under the big "NN / 100" score on the result + detail screens.
    var scoreLabel: String { t("Swing score", "Vuruş skoru") }
    var scoreOutOf: String { t("/ 100", "/ 100") }
    /// Compact badge, e.g. "82/100", used in history rows + headers.
    func scoreBadge(_ score: Int) -> String { "\(score)/100" }

    /// One-word tier read for the traffic-light band beside the score. Growth-
    /// framed (the colour already carries the signal): we never call a swing
    /// "bad". Thresholds are calibrated to the edge model's own scale — most
    /// recreational players land 40–70, 85+ is genuinely advanced — so green is
    /// attainable and the low tier stays rare and honest.
    func scoreTierLabel(_ tier: SwingScoreTier) -> String {
        switch tier {
        case .building: return t("Building", "Gelişiyor")
        case .solid:    return t("Solid", "Sağlam")
        case .sharp:    return t("Sharp", "Keskin")
        }
    }

    /// Short plain-language gloss under the tier word, so the colour isn't the
    /// only carrier of meaning (accessibility) and the read is encouraging.
    func scoreTierCaption(_ tier: SwingScoreTier) -> String {
        switch tier {
        case .building: return t("Foundations forming — clear things to work on.",
                                 "Temel oturuyor — üzerine çalışılacak net noktalar var.")
        case .solid:    return t("Right in the healthy recreational range.",
                                 "Sağlıklı amatör aralığının tam ortasında.")
        case .sharp:    return t("Above the typical recreational level — sharp technique.",
                                 "Tipik amatör seviyenin üstünde — keskin teknik.")
        }
    }

    // MARK: History
    var historyTitle: String { t("My swings", "Vuruşlarım") }
    var historyNavTitle: String { t("My swings", "Vuruşlarım") }
    /// Toolbar / row entry point to the history list.
    var historyEntryCTA: String { t("History", "Geçmiş") }
    var historyEmpty: String {
        t("Your saved swing reports will appear here.",
          "Kaydettiğin swing raporları burada görünecek.")
    }
    var viewAllReportsCTA: String { t("View all my reports", "Tüm raporlarımı gör") }
    var deleteCTA: String { t("Delete", "Sil") }
    var savedVideoTitle: String { t("Your swing", "Vuruşun") }

    /// A relative, localized phrase for `date` ("2 days ago" / "2 gün önce").
    func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: lang == .turkish ? "tr_TR" : "en_US")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: Errors
    var errorTitle: String { t("Something went wrong", "Bir şeyler ters gitti") }
    var errorGeneric: String {
        t("We couldn't analyze that clip. Please try again.",
          "Bu klibi analiz edemedik. Lütfen tekrar dene.")
    }
    var errorTooShort: String {
        t("That clip was too short or unreadable. Try a 6–10 second video.",
          "Bu klip çok kısa ya da okunamadı. 6–10 saniyelik bir video dene.")
    }
    var errorConnect: String {
        t("We couldn't reach the analysis service. Check your connection and try again.",
          "Analiz servisine ulaşamadık. Bağlantını kontrol edip tekrar dene.")
    }
    var retryCTA: String { t("Retry", "Tekrar dene") }
    var cancelCTA: String { t("Cancel", "Vazgeç") }
}
