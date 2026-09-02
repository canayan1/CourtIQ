import Foundation

/// Derives a Rocco conversation from an ordinary `Lesson`.
///
/// This exists so the mascot flow is the *only* flow from day one. A lesson with
/// a hand-authored script in `dialogues.json` uses it; every other lesson gets a
/// script built from the five-part scheme it already carries — situation,
/// principle, default action, adjustments, common mistake — plus the diagram and
/// quiz. Nothing is stranded on an older screen while writing catches up, and no
/// lesson ever needs a rewrite before it can ship.
///
/// The derived script is deliberately plain. It is a floor, not a ceiling: when a
/// hand-authored script lands for a lesson it simply takes over.
enum DialogueBuilder {
    static func script(for lesson: Lesson) -> DialogueScript {
        var nodes: [DialogueNode] = []

        // The scheme in its teaching order: the moment first, so the reader is
        // standing inside the point before any rule lands on them.
        nodes.append(.init(
            id: "situation",
            kind: .say,
            mood: .idle,
            text: lesson.situation,
            next: "principle"
        ))
        nodes.append(.init(
            id: "principle",
            kind: .say,
            mood: .happy,
            text: lesson.principle,
            next: lesson.diagram != nil ? "scene" : "default-action"
        ))

        if let diagram = lesson.diagram {
            nodes.append(.init(
                id: "scene",
                kind: .show,
                mood: .idle,
                text: diagram.caption ?? "Have a look at the court.",
                next: "default-action",
                scene: diagram
            ))
        }

        nodes.append(.init(
            id: "default-action",
            kind: .say,
            mood: .idle,
            text: lesson.defaultAction,
            next: lesson.adjustments.isEmpty ? "mistake" : adjustmentID(0)
        ))

        // One bubble per adjustment, phrased as a spoken conditional.
        for (index, adjustment) in lesson.adjustments.enumerated() {
            let isLast = index == lesson.adjustments.count - 1
            nodes.append(.init(
                id: adjustmentID(index),
                kind: .say,
                mood: .thinking,
                text: "\(adjustment.when)? \(adjustment.then)",
                next: isLast ? "mistake" : adjustmentID(index + 1)
            ))
        }

        nodes.append(.init(
            id: "mistake",
            kind: .say,
            mood: .oops,
            text: lesson.commonMistake,
            next: "scenario"
        ))

        // The quiz situation, then the question — split so the ask bubble stays
        // short enough to read as a question rather than a passage.
        nodes.append(.init(
            id: "scenario",
            kind: .say,
            mood: .thinking,
            text: lesson.quiz.scenario,
            next: "ask"
        ))
        nodes.append(.init(
            id: "ask",
            kind: .ask,
            mood: .thinking,
            text: lesson.quiz.question,
            options: lesson.quiz.options.enumerated().map { index, option in
                let correct = index == lesson.quiz.correctIndex
                return .init(
                    label: option,
                    correct: correct,
                    // A wrong reply must not leak which option is right, so it
                    // nudges instead of explaining. The full explanation lands on
                    // the finish node, after a correct answer.
                    reply: correct ? "That's the one." : "That one costs you. Have another think.",
                    next: correct ? "finish" : "ask"
                )
            }
        ))

        nodes.append(.init(
            id: "finish",
            kind: .finish,
            mood: .cheer,
            text: lesson.quiz.explanation
        ))

        return DialogueScript(id: "auto-\(lesson.id)", lessonID: lesson.id, nodes: nodes)
    }

    private static func adjustmentID(_ index: Int) -> String { "adjust-\(index)" }
}
