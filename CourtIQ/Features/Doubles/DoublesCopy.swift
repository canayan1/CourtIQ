import Foundation

/// Bilingual copy for the Doubles Compatibility feature (EN/TR). Self-contained,
/// mirrors the `SwingAnalysisCopy` / `TennisProfileCopy` pattern. Spanish (and
/// any other language) falls back to English.
struct DoublesCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String) -> String { lang == .turkish ? tr : en }

    // MARK: Feature title / nav
    var navTitle: String { t("Doubles Compatibility", "Doubles Uyumu") }
    var cardEyebrow: String { t("Doubles partner analysis", "Doubles partner uyumu") }
    var cardTitle: String {
        t("See how your games fit together",
          "Oyunlarınızın nasıl uyuştuğunu gör")
    }

    // MARK: Partner list
    var addPartnerCTA: String { t("Add partner", "Partner ekle") }
    var listEmpty: String {
        t("Add a doubles partner to see how your games fit.",
          "Oyunlarınızın nasıl uyuştuğunu görmek için bir doubles partneri ekle.")
    }
    var partnersHeader: String { t("Your partners", "Partnerlerin") }

    // MARK: Partner form
    var newPartnerTitle: String { t("New partner", "Yeni partner") }
    var editPartnerTitle: String { t("Edit partner", "Partneri düzenle") }
    var nameLabel: String { t("Name", "İsim") }
    var namePlaceholder: String { t("Partner's name", "Partnerin adı") }
    var levelLabel: String { t("Level", "Seviye") }
    var handednessLabel: String { t("Plays", "Oynar") }
    var styleLabel: String { t("Style", "Stil") }
    var strengthsLabel: String { t("Strengths", "Güçlü yönler") }
    var strengthsPlaceholder: String {
        t("e.g. big serve, confident at the net",
          "örn. güçlü servis, filede rahat")
    }
    var weaknessesLabel: String { t("Weaknesses", "Zayıf yönler") }
    var weaknessesPlaceholder: String {
        t("e.g. shaky backhand, slow to the net",
          "örn. zayıf backhand, fileye geç çıkar")
    }
    var notSet: String { t("Not set", "Belirtilmedi") }
    var saveCTA: String { t("Save partner", "Partneri kaydet") }

    func level(_ l: TennisLevel) -> String { TennisProfileCopy(lang: lang).levelTitle(l) }
    func style(_ a: TennisArchetype) -> String { TennisProfileCopy(lang: lang).archetypeTitle(a) }
    func handedness(_ h: SwingHandedness) -> String {
        switch h {
        case .right: return t("Right-handed", "Sağ elli")
        case .left:  return t("Left-handed", "Sol elli")
        }
    }

    // MARK: Analyze
    var analyzeCTA: String { t("Analyze our pairing", "Eşleşmemizi analiz et") }
    var analyzingTitle: String { t("Analyzing your pairing…", "Eşleşmeniz analiz ediliyor…") }
    var analyzingStep1: String { t("Reading both player profiles", "Her iki oyuncu profili okunuyor") }
    var analyzingStep2: String { t("Mapping strengths and gaps", "Güçlü yönler ve açıklar eşleştiriliyor") }
    var analyzingStep3: String { t("Scoring your compatibility", "Uyumunuz puanlanıyor") }
    var analyzingStep4: String { t("Building your game plan", "Oyun planınız hazırlanıyor") }
    var analyzingStep5: String { t("Writing your coaching report", "Koçluk raporunuz yazılıyor") }
    var analyzingSteps: [String] {
        [analyzingStep1, analyzingStep2, analyzingStep3, analyzingStep4, analyzingStep5]
    }

    // MARK: Report
    var reportTitle: String { t("Your pairing report", "Eşleşme raporun") }
    var pairSectionTitle: String { t("The pairing", "Eşleşme") }
    var youLabel: String { t("You", "Sen") }
    var scoreLabel: String { t("Compatibility", "Uyum") }
    var scoreOutOf: String { t("/ 100", "/ 100") }
    func scoreBadge(_ score: Int) -> String { "\(score)/100" }
    var pastReportsHeader: String { t("Past reports", "Geçmiş raporlar") }
    var noReportsYet: String {
        t("No reports yet — run an analysis to see your compatibility.",
          "Henüz rapor yok — uyumunuzu görmek için bir analiz çalıştır.")
    }
    var reAnalyzeCTA: String { t("Analyze again", "Tekrar analiz et") }

    // MARK: Delete
    var deletePartnerCTA: String { t("Delete partner", "Partneri sil") }
    var deletePartnerConfirm: String {
        t("This removes the partner and all of their reports.",
          "Bu, partneri ve tüm raporlarını siler.")
    }
    var deleteCTA: String { t("Delete", "Sil") }
    var cancelCTA: String { t("Cancel", "Vazgeç") }

    // MARK: Errors
    var errorTitle: String { t("Something went wrong", "Bir şeyler ters gitti") }
    var errorGeneric: String {
        t("We couldn't analyze your pairing. Please try again.",
          "Eşleşmenizi analiz edemedik. Lütfen tekrar dene.")
    }
    var errorConnect: String {
        t("We couldn't reach the analysis service. Check your connection and try again.",
          "Analiz servisine ulaşamadık. Bağlantını kontrol edip tekrar dene.")
    }
    var retryCTA: String { t("Retry", "Tekrar dene") }

    /// A relative, localized phrase for `date` ("2 days ago" / "2 gün önce").
    func relativeDate(_ date: Date) -> String {
        // Within a minute, RelativeDateTimeFormatter reads as "in 0 seconds";
        // show a friendly "just now" for a freshly generated report instead.
        if abs(date.timeIntervalSinceNow) < 60 {
            return t("just now", "az önce")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: lang == .turkish ? "tr_TR" : "en_US")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
