import Foundation

/// Copy for the Tactics tab in the app's three shipped languages: the chrome
/// via `t(en, tr, fr)` below, and — since the whole tab is one of the three
/// things the app sells and shipped English-only — the lesson CONTENT too,
/// via `c(key, fallback)`, which reads `TacticsContentI18n` and falls back to
/// the English in `tactics_curriculum.json` for any key not yet translated.
struct TacticsCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String, _ fr: String? = nil) -> String {
        switch lang {
        case .turkish: return tr
        case .french:  return fr ?? en
        default:       return en
        }
    }

    // Lesson chrome — the labels around the content. These were English
    // literals in the views while the lesson itself was translated.
    var theSituation: String { t("The situation", "Durum", "La situation") }
    var thePrinciple: String { t("The principle", "İlke", "Le principe") }
    var reviewPrinciple: String { t("Review · The principle", "Tekrar · İlke", "Révision · Le principe") }
    var yourDefault: String { t("Your default", "Varsayılanın", "Ton réflexe") }
    var theCommonMistake: String { t("The common mistake", "Sık yapılan hata", "L'erreur classique") }
    var tryItInAPoint: String { t("Try it in a point", "Bir sayıda dene", "Essaie-le dans un point") }
    var continueLabel: String { t("Continue", "Devam", "Continuer") }
    var startHere: String { t("Start here", "Buradan başla", "Commence ici") }
    var goOnThen: String { t("Go on then", "Hadi bakalım", "Vas-y") }
    var exactlyRight: String { t("Exactly right", "Tam isabet", "Exactement") }
    var thatsIt: String { t("That's it", "İşte bu", "C'est ça") }
    var notHighestPercentage: String {
        t("Not the highest-percentage play", "En yüksek yüzdeli seçim değil", "Ce n'est pas le choix le plus rentable")
    }
    var completeLesson: String { t("Complete lesson", "Dersi tamamla", "Terminer la leçon") }
    var done: String { t("Done", "Bitti", "Terminé") }

    // MARK: Lesson content
    //
    // The curriculum JSON holds the English and the structure; these read the
    // per-language file beside it. Every accessor falls back to the value it
    // was given, so an untranslated lesson renders in English rather than
    // blank, and a half-finished language is shippable.

    private var content: [String: String] { TacticsContentI18n.map(for: lang) }

    private func c(_ key: String, _ fallback: String) -> String {
        guard let v = content[key], !v.trimmingCharacters(in: .whitespaces).isEmpty else { return fallback }
        return v
    }

    /// A chapter with every displayed string swapped for this language. Ids,
    /// numbering, symbol and gating are structural and carried over as-is.
    func localized(_ ch: Chapter) -> Chapter {
        Chapter(id: ch.id, number: ch.number,
                title: c("chapter.\(ch.id).title", ch.title),
                subtitle: c("chapter.\(ch.id).subtitle", ch.subtitle),
                symbol: ch.symbol, isFree: ch.isFree,
                lessons: ch.lessons.map(localized),
                hook: ch.hook.map { c("chapter.\(ch.id).hook", $0) },
                isSideSet: ch.isSideSet)
    }

    /// A lesson with every displayed string swapped for this language.
    ///
    /// Views localise ONCE at the top and then read the lesson normally, so
    /// nothing downstream — the renderer, `DialogueBuilder`, the quiz — has to
    /// know a translation exists. `correctIndex`, the option ORDER and the
    /// diagrams are carried over untouched: the translated option list is
    /// positional, so reordering it would point the index at the wrong answer.
    func localized(_ l: Lesson) -> Lesson {
        Lesson(id: l.id,
               title: c("lesson.\(l.id).title", l.title),
               situation: c("lesson.\(l.id).situation", l.situation),
               principle: c("lesson.\(l.id).principle", l.principle),
               defaultAction: c("lesson.\(l.id).defaultAction", l.defaultAction),
               adjustments: l.adjustments.enumerated().map { i, a in
                   Adjustment(when: c("lesson.\(l.id).adj.\(i).when", a.when),
                              then: c("lesson.\(l.id).adj.\(i).then", a.then))
               },
               commonMistake: c("lesson.\(l.id).commonMistake", l.commonMistake),
               diagram: l.diagram,
               quiz: QuizItem(scenario: c("lesson.\(l.id).quiz.scenario", l.quiz.scenario),
                              question: c("lesson.\(l.id).quiz.question", l.quiz.question),
                              options: l.quiz.options.enumerated().map { i, o in
                                  c("lesson.\(l.id).quiz.opt.\(i)", o) },
                              correctIndex: l.quiz.correctIndex,
                              explanation: c("lesson.\(l.id).quiz.explanation", l.quiz.explanation),
                              diagram: l.quiz.diagram),
               advanced: l.advanced.map {
                   AdvancedNote(heading: c("lesson.\(l.id).advanced.heading", $0.heading),
                                body: c("lesson.\(l.id).advanced.body", $0.body)) })
    }

    /// A dialogue script in the player's language.
    ///
    /// Authored scripts are looked up by lesson + node id. A script DERIVED by
    /// `DialogueBuilder` from an already-translated lesson finds no keys and
    /// falls back to the text it was built from, which is the translation — so
    /// this is safe to apply to either kind.
    ///
    /// Branching is structural and untouched: `next`, `correct` and the option
    /// ORDER all carry over, because a wrong option's `next` points back at its
    /// own ask node and that is what makes the retry loop work.
    func localized(_ script: DialogueScript) -> DialogueScript {
        DialogueScript(id: script.id, lessonID: script.lessonID, nodes: script.nodes.map { node in
            let base = "dialogue.\(script.lessonID).\(node.id)"
            return DialogueNode(
                id: node.id, kind: node.kind, mood: node.mood,
                text: c(base, node.text),
                next: node.next,
                options: node.options.enumerated().map { i, o in
                    DialogueNode.Option(label: c("\(base).opt.\(i).label", o.label),
                                        correct: o.correct,
                                        reply: c("\(base).opt.\(i).reply", o.reply),
                                        next: o.next)
                },
                scene: node.scene, setID: node.setID)
        })
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
