import Foundation

/// Bilingual chrome copy for the Tactics tab (EN/TR), the same `t(en, tr)`
/// pattern as `OnboardingCopy`. Lesson CONTENT stays in the bundled JSON
/// (English for now); this covers only the app's own labels around it.
struct TacticsCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String, _ fr: String? = nil) -> String {
        switch lang {
        case .turkish: return tr
        case .french:  return fr ?? en
        default:       return en
        }
    }

    // Rail
    func xpToNext(_ togo: Int, _ level: String) -> String { t("\(togo) XP → \(level)", "\(togo) XP → \(level)", "\(togo) XP → \(level)") }
    var topLevel: String { t("Top level", "En üst seviye", "Niveau maximum") }
    func chapterLine(_ n: Int, _ title: String) -> String { t("Chapter \(n) · \(title)", "Bölüm \(n) · \(title)", "Chapitre \(n) · \(title)") }
    var courseComplete: String { t("Course complete", "Kurs tamamlandı", "Parcours terminé") }
    var courseCompleteBody: String {
        t("You've finished every lesson. Revisit any of them any time — replays are always free.", "Her dersi bitirdin. İstediğin zaman geri dön — tekrarlar her zaman ücretsiz.", "Tu as terminé toutes les leçons. Reviens-y quand tu veux — les relectures sont toujours gratuites.")
    }
    func chapter(_ n: Int) -> String { t("Chapter \(n)", "Bölüm \(n)", "Chapitre \(n)") }
    var free: String { t("FREE", "ÜCRETSİZ", "GRATUIT") }
    var scenariosEyebrow: String { t("Scenarios", "Senaryolar", "Situations") }
    var tennisIQ: String { t("Tennis IQ", "Tenis IQ", "QI Tennis") }
    var tennisIQBody: String {
        t("Real match situations, one decision at a time. Your IQ number lives here.", "Gerçek maç durumları, her seferinde tek karar. IQ puanın burada.", "De vraies situations de match, une décision à la fois. Ton QI se joue ici.")
    }
    var sideQuestsEyebrow: String { t("Rocco's side quests", "Rocco'nun yan görevleri", "Les quêtes annexes de Rocco") }
    var sideQuestsBody: String { t("Short sets on one specific gap", "Tek bir açığa odaklanan kısa setler", "Des séries courtes sur une lacune précise") }
    var unlockTitle: String { t("Unlock the full course", "Kursun tamamını aç", "Débloquer tout le parcours") }
    func unlockBody(_ n: Int) -> String { t("\(n) lessons, every chapter, forever offline", "\(n) ders, her bölüm, hep çevrimdışı", "\(n) leçons, tous les chapitres, hors ligne pour toujours") }

    // Rail rows
    func finishFirst(_ title: String) -> String { t("Finish “\(title)” first", "Önce “\(title)” dersini bitir", "Termine d'abord « \(title) »") }
    var unlockToOpen: String { t("Unlock the full course to open this", "Bunu açmak için kursun tamamını aç", "Débloque tout le parcours pour ouvrir cette leçon") }
    var freeToday: String { t("Today's free lesson", "Bugünün ücretsiz dersi", "La leçon gratuite du jour") }
    var doneReview: String { t("Done · tap to review", "Bitti · gözden geçirmek için dokun", "Terminée · touche pour revoir") }

    // Lesson player
    var notes: String { t("Notes", "Notlar", "Notes") }
    var readNotes: String { t("Read the full notes", "Tüm notları oku", "Lire toutes les notes") }

    // Completion
    var newLevel: String { t("New level", "Yeni seviye", "Nouveau niveau") }
    func badgeEarned(_ n: Int) -> String { t("Chapter \(n) badge earned", "Bölüm \(n) rozeti kazanıldı", "Badge du chapitre \(n) obtenu") }
    func daysInARow(_ d: Int) -> String { t("\(d) days in a row", "Üst üste \(d) gün", "\(d) jours d'affilée") }
    var habitLine: String { t("That is the habit doing the work now.", "Artık işi alışkanlık yapıyor.", "C'est l'habitude qui travaille pour toi maintenant.") }
    func xpTo(_ togo: Int, _ level: String) -> String { t("\(togo) XP to \(level)", "\(level) için \(togo) XP", "\(togo) XP jusqu'à \(level)") }
    func unlockAll(_ n: Int) -> String { t("Unlock all \(n) lessons and keep going now.", "\(n) dersin tamamını aç ve hemen devam et.", "Débloque les \(n) leçons et continue tout de suite.") }
    func stillInside(_ lessons: Int, _ chapters: Int) -> String {
        t("Still inside: \(lessons) lessons across \(chapters) chapters, plus 156 match scenarios.",
          "İçeride kalan: \(chapters) bölümde \(lessons) ders, artı 156 maç senaryosu.",
          "Il reste \(lessons) leçons dans \(chapters) chapitres, plus 156 situations de match.")
    }
    var seeOptions: String { t("See the options", "Seçenekleri gör", "Voir les options") }

    // Notes view
    var adjustWhen: String { t("Adjust when", "Ne zaman uyarla", "À adapter quand") }
    var advancedBody: String {
        t("The exception to this rule, and what stronger players do instead.", "Bu kuralın istisnası ve daha güçlü oyuncuların bunun yerine ne yaptığı.", "L'exception à cette règle, et ce que font les joueurs plus forts à la place.")
    }
    var situation: String { t("The situation", "Durum", "La situation") }
    var lookAgain: String { t("Have another look at the rule, then pick again.", "Kurala bir daha bak, sonra yeniden seç.", "Relis la règle, puis choisis à nouveau.") }
    var tryAgain: String { t("Try again", "Tekrar dene", "Réessayer") }
    var rereadRule: String { t("Re-read the rule", "Kuralı yeniden oku", "Relire la règle") }
}
