import Foundation

/// Bilingual copy for the Doubles Compatibility feature (EN/TR). Self-contained,
/// mirrors the `SwingAnalysisCopy` / `TennisProfileCopy` pattern. Spanish (and
/// any other language) falls back to English.
struct DoublesCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String, _ fr: String? = nil) -> String {
        switch lang {
        case .turkish: return tr
        case .french:  return fr ?? en
        default:       return en
        }
    }

    // MARK: Feature title / nav
    var navTitle: String { t("Doubles Compatibility", "Doubles Uyumu", "Compatibilité en double") }
    var cardEyebrow: String { t("Doubles partner analysis", "Doubles partner uyumu", "Analyse de ton partenaire de double") }
    var cardTitle: String {
        t("See how your games fit together", "Oyunlarınızın nasıl uyuştuğunu gör", "Vois comment vos jeux s'assemblent")
    }

    // MARK: Partner list
    var addPartnerCTA: String { t("Add partner", "Partner ekle", "Ajouter un partenaire") }
    var partnersHeader: String { t("Your partners", "Partnerlerin", "Tes partenaires") }

    // MARK: Partner form
    var newPartnerTitle: String { t("New partner", "Yeni partner", "Nouveau partenaire") }
    var editPartnerTitle: String { t("Edit partner", "Partneri düzenle", "Modifier le partenaire") }
    var nameLabel: String { t("Name", "İsim", "Nom") }
    var namePlaceholder: String { t("Partner's name", "Partnerin adı", "Nom du partenaire") }
    var levelLabel: String { t("Level", "Seviye", "Niveau") }
    var handednessLabel: String { t("Plays", "Oynar", "Joue") }
    var styleLabel: String { t("Style", "Stil", "Style") }
    var strengthsLabel: String { t("Strengths", "Güçlü yönler", "Points forts") }
    var strengthsPlaceholder: String {
        t("e.g. big serve, confident at the net", "örn. güçlü servis, filede rahat", "ex. gros service, à l'aise au filet")
    }
    var weaknessesLabel: String { t("Weaknesses", "Zayıf yönler", "Points faibles") }
    var weaknessesPlaceholder: String {
        t("e.g. shaky backhand, slow to the net", "örn. zayıf backhand, fileye geç çıkar", "ex. revers fragile, lent à monter au filet")
    }
    var notSet: String { t("Not set", "Belirtilmedi", "Non renseigné") }
    var saveCTA: String { t("Save partner", "Partneri kaydet", "Enregistrer le partenaire") }

    func level(_ l: TennisLevel) -> String { TennisProfileCopy(lang: lang).levelTitle(l) }
    func style(_ a: TennisArchetype) -> String { TennisProfileCopy(lang: lang).archetypeTitle(a) }
    func handedness(_ h: SwingHandedness) -> String {
        switch h {
        case .right: return t("Right-handed", "Sağ elli", "Droitier")
        case .left:  return t("Left-handed", "Sol elli", "Gaucher")
        }
    }

    // MARK: Analyze
    var analyzeCTA: String { t("Analyze our pairing", "Eşleşmemizi analiz et", "Analyser notre paire") }
    var analyzingTitle: String { t("Analyzing your pairing…", "Eşleşmeniz analiz ediliyor…", "Analyse de votre paire…") }
    var analyzingStep1: String { t("Reading both player profiles", "Her iki oyuncu profili okunuyor", "Lecture des deux profils") }
    var analyzingStep2: String { t("Mapping strengths and gaps", "Güçlü yönler ve açıklar eşleştiriliyor", "Cartographie des forces et des manques") }
    var analyzingStep3: String { t("Scoring your compatibility", "Uyumunuz puanlanıyor", "Calcul de votre compatibilité") }
    var analyzingStep4: String { t("Building your game plan", "Oyun planınız hazırlanıyor", "Construction de votre plan de jeu") }
    var analyzingStep5: String { t("Writing your coaching report", "Koçluk raporunuz yazılıyor", "Rédaction de votre rapport") }
    var analyzingSteps: [String] {
        [analyzingStep1, analyzingStep2, analyzingStep3, analyzingStep4, analyzingStep5]
    }

    // MARK: Report
    var reportTitle: String { t("Your pairing report", "Eşleşme raporun", "Le rapport de votre paire") }
    var pairSectionTitle: String { t("The pairing", "Eşleşme", "La paire") }
    var youLabel: String { t("You", "Sen", "Toi") }
    var scoreLabel: String { t("Compatibility", "Uyum", "Compatibilité") }
    var scoreOutOf: String { t("/ 100", "/ 100", "/ 100") }
    func scoreBadge(_ score: Int) -> String { "\(score)/100" }

    /// One-word compatibility tier beside the score — colour carries the
    /// signal, the word stays encouraging (a low fit is "complementary", never
    /// "bad": two friends who paired up should never feel insulted).
    func compatTierLabel(_ tier: DoublesCompatTier) -> String {
        switch tier {
        case .work:  return t("Complementary", "Tamamlayıcı", "Complémentaires")
        case .solid: return t("Solid team", "Sağlam ikili", "Équipe solide")
        case .great: return t("Great fit", "Harika uyum", "Très belle alchimie")
        }
    }
    func compatTierCaption(_ tier: DoublesCompatTier) -> String {
        switch tier {
        case .work:  return t("You'll cover for each other — sort clear roles first.", "Birbirinizi tamamlarsınız — önce net roller belirleyin.", "Vous vous couvrirez l'un l'autre — commencez par définir des rôles clairs.")
        case .solid: return t("A dependable pairing with real shared strengths.", "Ortak güçlü yanları olan güvenilir bir ikili.", "Une paire fiable, avec de vraies forces communes.")
        case .great: return t("Your games slot together — a genuinely strong team.", "Oyunlarınız birbirine oturuyor — gerçekten güçlü bir takım.", "Vos jeux s'emboîtent — une équipe vraiment forte.")
        }
    }
    // Honest fit reveal (tier + card; no 0–100 number — see DoublesFit).
    var fitLabel: String { t("Your fit", "Uyumunuz", "Votre alchimie") }
    var strengthsHeader: String { t("What's working", "İşe yarayanlar", "Ce qui fonctionne") }
    var watchHeader: String { t("Watch-outs", "Dikkat noktaları", "Points de vigilance") }
    var fitNeedsProfile: String {
        t("This read is from your partner's details only. Complete your Tennis Profile for a sharper two-way fit.", "Bu okuma yalnızca partnerinin bilgilerinden. Daha net iki-yönlü uyum için Tenis Profilini tamamla.", "Cette lecture ne s'appuie que sur les infos de ton partenaire. Complète ton profil tennis pour une analyse croisée plus fine.")
    }
    /// Localize an English factor phrase produced by `DoublesCompatibility`.
    func factorPhrase(_ en: String) -> String {
        guard lang == .turkish else { return en }
        switch en {
        case "you're at the same level": return "aynı seviyedesiniz"
        case "close levels": return "yakın seviyeler"
        case "complementary play styles": return "birbirini tamamlayan oyun stilleri"
        case "an all-court partner who adapts to you": return "sana uyum sağlayan all-court bir partner"
        case "a left-handed partner (covers the ad court)": return "solak partner (ad kortunu kapatır)"
        case "a level gap to bridge": return "kapatılacak bir seviye farkı"
        case "a wide level gap — lean on the stronger side": return "geniş seviye farkı — güçlü tarafa yaslanın"
        case "two similar styles — split your roles clearly": return "iki benzer stil — rolleri net paylaşın"
        default: return en
        }
    }

    var pastReportsHeader: String { t("Past reports", "Geçmiş raporlar", "Rapports précédents") }
    var noReportsYet: String {
        t("No reports yet — run an analysis to see your compatibility.", "Henüz rapor yok — uyumunuzu görmek için bir analiz çalıştır.", "Aucun rapport — lance une analyse pour voir votre compatibilité.")
    }
    var reAnalyzeCTA: String { t("Analyze again", "Tekrar analiz et", "Relancer l'analyse") }

    // MARK: Doubles IQ bridge (report → practice quiz)
    var quizBridgeEyebrow: String { t("Keep building", "Gelişmeye devam", "Continuer à construire") }
    var quizBridgeTitle: String { t("Sharpen your doubles IQ", "Doubles IQ'nu keskinleştir", "Affûte ton QI du double") }
    var quizBridgeSubtitle: String {
        t("Train the calls", "Kararları çalış", "Travaille les décisions")
    }

    // MARK: Delete
    var deletePartnerCTA: String { t("Delete partner", "Partneri sil", "Supprimer le partenaire") }
    var deletePartnerConfirm: String {
        t("This removes the partner and all of their reports.", "Bu, partneri ve tüm raporlarını siler.", "Cela supprime le partenaire et tous ses rapports.")
    }
    var deleteCTA: String { t("Delete", "Sil", "Supprimer") }
    var cancelCTA: String { t("Cancel", "Vazgeç", "Annuler") }

    // MARK: Errors
    var errorTitle: String { t("Something went wrong", "Bir şeyler ters gitti", "Un problème est survenu") }
    var errorGeneric: String {
        t("We couldn't analyze your pairing. Please try again.", "Eşleşmenizi analiz edemedik. Lütfen tekrar dene.", "Impossible d'analyser votre paire. Réessaie.")
    }
    var errorConnect: String {
        t("We couldn't reach the analysis service. Check your connection and try again.", "Analiz servisine ulaşamadık. Bağlantını kontrol edip tekrar dene.", "Impossible de joindre le service d'analyse. Vérifie ta connexion et réessaie.")
    }
    var retryCTA: String { t("Retry", "Tekrar dene", "Réessayer") }

    /// A relative, localized phrase for `date` ("2 days ago" / "2 gün önce").
    func relativeDate(_ date: Date) -> String {
        // Within a minute, RelativeDateTimeFormatter reads as "in 0 seconds";
        // show a friendly "just now" for a freshly generated report instead.
        if abs(date.timeIntervalSinceNow) < 60 {
            return t("just now", "az önce", "à l'instant")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: lang == .turkish ? "tr_TR" : "en_US")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
