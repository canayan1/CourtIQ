import Foundation

/// Loads the bundled curriculum once at launch.
///
/// The content is shipped in the binary, so a decode failure is a build bug, not
/// a runtime condition a user can hit — but it still must not crash a shipped
/// app, so a failure degrades to an empty curriculum and surfaces `loadError`
/// for the UI to show instead of a blank path.
@Observable
@MainActor
final class ContentStore {
    private(set) var curriculum: Curriculum
    private(set) var loadError: String?

    /// Hand-authored scripts, keyed by lesson id. A miss is normal, not an error:
    /// `DialogueBuilder` derives a script for any lesson without one.
    private var authoredScripts: [String: DialogueScript] = [:]

    init(bundle: Bundle = .main) {
        do {
            guard let url = bundle.url(forResource: "tactics_curriculum", withExtension: "json") else {
                throw LoadError.missingFile
            }
            let data = try Data(contentsOf: url)
            curriculum = try JSONDecoder().decode(Curriculum.self, from: data)
        } catch {
            curriculum = Curriculum(version: 0, chapters: [])
            loadError = String(describing: error)
        }

        // Dialogues load separately and fail soft. A broken script file must
        // degrade to derived conversations, not to an app with no lessons.
        if let url = bundle.url(forResource: "tactics_dialogues", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let book = try? JSONDecoder().decode(DialogueBook.self, from: data) {
            authoredScripts = Dictionary(
                book.scripts.map { ($0.lessonID, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }
    }

    private enum LoadError: Error {
        case missingFile
    }

    // MARK: Course walking

    var chapters: [Chapter] { curriculum.chapters }
    var sideSets: [Chapter] { curriculum.sideSets }

    func chapter(containing lessonID: String) -> Chapter? {
        curriculum.chapter(containing: lessonID)
    }

    func sideSet(id: String) -> Chapter? {
        curriculum.sideSets.first { $0.id == id }
    }

    // MARK: Dialogue

    /// The conversation that teaches a lesson: the hand-authored script if one
    /// was written, otherwise one derived from the lesson's own material.
    func script(for lesson: Lesson) -> DialogueScript {
        authoredScripts[lesson.id] ?? DialogueBuilder.script(for: lesson)
    }

    /// True when this lesson has a written script rather than a derived one. Used
    /// only by diagnostics — the player is never told which they are getting.
    func hasAuthoredScript(for lesson: Lesson) -> Bool {
        authoredScripts[lesson.id] != nil
    }

    /// The lesson the player should do next: the first uncompleted one in course
    /// order, or nil when the whole course is finished.
    func nextLesson(for progress: PlayerProgress) -> (chapter: Chapter, lesson: Lesson)? {
        for chapter in curriculum.chapters {
            if let lesson = chapter.lessons.first(where: { !progress.isCompleted($0.id) }) {
                return (chapter, lesson)
            }
        }
        return nil
    }

    var totalLessonCount: Int { curriculum.allLessons.count }
}
