import Foundation

/// Bilingual chrome copy for the Tactics tab (EN/TR), the same `t(en, tr)`
/// pattern as `OnboardingCopy`. Lesson CONTENT stays in the bundled JSON
/// (English for now); this covers only the app's own labels around it.
struct TacticsCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String) -> String { lang == .turkish ? tr : en }

    // Rail
    func xpToNext(_ togo: Int, _ level: String) -> String { t("\(togo) XP → \(level)", "\(togo) XP → \(level)") }
    var topLevel: String { t("Top level", "En üst seviye") }
    func chapterLine(_ n: Int, _ title: String) -> String { t("Chapter \(n) · \(title)", "Bölüm \(n) · \(title)") }
    var courseComplete: String { t("Course complete", "Kurs tamamlandı") }
    var courseCompleteBody: String {
        t("You've finished every lesson. Revisit any of them any time — replays are always free.",
          "Her dersi bitirdin. İstediğin zaman geri dön — tekrarlar her zaman ücretsiz.")
    }
    func chapter(_ n: Int) -> String { t("Chapter \(n)", "Bölüm \(n)") }
    var free: String { t("FREE", "ÜCRETSİZ") }
    var scenariosEyebrow: String { t("Scenarios", "Senaryolar") }
    var tennisIQ: String { t("Tennis IQ", "Tenis IQ") }
    var tennisIQBody: String {
        t("Real match situations, one decision at a time. Your IQ number lives here.",
          "Gerçek maç durumları, her seferinde tek karar. IQ puanın burada.")
    }
    var sideQuestsEyebrow: String { t("Rocco's side quests", "Rocco'nun yan görevleri") }
    var sideQuestsBody: String { t("Short sets on one specific gap", "Tek bir açığa odaklanan kısa setler") }
    var unlockTitle: String { t("Unlock the full course", "Kursun tamamını aç") }
    func unlockBody(_ n: Int) -> String { t("\(n) lessons, every chapter, forever offline", "\(n) ders, her bölüm, hep çevrimdışı") }

    // Rail rows
    func finishFirst(_ title: String) -> String { t("Finish “\(title)” first", "Önce “\(title)” dersini bitir") }
    var unlockToOpen: String { t("Unlock the full course to open this", "Bunu açmak için kursun tamamını aç") }
    var freeToday: String { t("Today's free lesson", "Bugünün ücretsiz dersi") }
    var doneReview: String { t("Done · tap to review", "Bitti · gözden geçirmek için dokun") }

    // Lesson player
    var notes: String { t("Notes", "Notlar") }
    var readNotes: String { t("Read the full notes", "Tüm notları oku") }

    // Completion
    var newLevel: String { t("New level", "Yeni seviye") }
    func badgeEarned(_ n: Int) -> String { t("Chapter \(n) badge earned", "Bölüm \(n) rozeti kazanıldı") }
    func daysInARow(_ d: Int) -> String { t("\(d) days in a row", "Üst üste \(d) gün") }
    var habitLine: String { t("That is the habit doing the work now.", "Artık işi alışkanlık yapıyor.") }
    func xpTo(_ togo: Int, _ level: String) -> String { t("\(togo) XP to \(level)", "\(level) için \(togo) XP") }
    func unlockAll(_ n: Int) -> String { t("Unlock all \(n) lessons and keep going now.", "\(n) dersin tamamını aç ve hemen devam et.") }
    var seeOptions: String { t("See the options", "Seçenekleri gör") }

    // Notes view
    var adjustWhen: String { t("Adjust when", "Ne zaman uyarla") }
    var advancedBody: String {
        t("The exception to this rule, and what stronger players do instead.",
          "Bu kuralın istisnası ve daha güçlü oyuncuların bunun yerine ne yaptığı.")
    }
    var situation: String { t("The situation", "Durum") }
    var lookAgain: String { t("Have another look at the rule, then pick again.", "Kurala bir daha bak, sonra yeniden seç.") }
    var tryAgain: String { t("Try again", "Tekrar dene") }
    var rereadRule: String { t("Re-read the rule", "Kuralı yeniden oku") }
}
