import Foundation

struct Quiz: Identifiable {
    let id: String
    let title: String
    let questions: [QuizQuestion]
}

struct QuizQuestion: Identifiable {
    let id: String
    let scenarioText: String
    let options: [QuizOption]
    let correctOptionID: String
    let explanation: String
}

struct QuizOption: Identifiable {
    let id: String
    let text: String
}

// MARK: - Mock Data

extension Quiz {
    static let sample = Quiz(
        id: "q1",
        title: "Deuce Court Tactics",
        questions: [
            QuizQuestion(
                id: "q1-1",
                scenarioText: "It's 30-30 in the deuce court. Your opponent has a weak backhand. Where do you serve?",
                options: [
                    QuizOption(id: "a", text: "Wide to the forehand"),
                    QuizOption(id: "b", text: "Down the T to the backhand"),
                    QuizOption(id: "c", text: "Into the body"),
                ],
                correctOptionID: "b",
                explanation: "Serving into the backhand at the T limits the returner's angle and forces a weaker reply, setting up an easy put-away."
            ),
            QuizQuestion(
                id: "q1-2",
                scenarioText: "You're at the net after a strong approach shot. Your opponent lobs over your backhand side. What do you do?",
                options: [
                    QuizOption(id: "a", text: "Jump and smash it"),
                    QuizOption(id: "b", text: "Let it bounce and play an overhead"),
                    QuizOption(id: "c", text: "Run around and hit a forehand overhead"),
                ],
                correctOptionID: "c",
                explanation: "Running around to hit a forehand overhead gives you much more power and control than a backhand overhead, especially under pressure."
            ),
            QuizQuestion(
                id: "q1-3",
                scenarioText: "You win the first two sets 6-3, 6-4. Your opponent looks tired. How do you approach the third set?",
                options: [
                    QuizOption(id: "a", text: "Play it safe and just keep the ball in"),
                    QuizOption(id: "b", text: "Maintain your aggressive game plan"),
                    QuizOption(id: "c", text: "Go for winners on every ball"),
                ],
                correctOptionID: "b",
                explanation: "Changing a winning game plan is a classic mistake. Keep the pressure on with the same tactics that earned you the lead."
            ),
        ]
    )
}
