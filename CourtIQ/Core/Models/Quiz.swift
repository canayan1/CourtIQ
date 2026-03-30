import Foundation

enum QuizCategory: String, CaseIterable, Identifiable, Codable {
    case serve
    case returnPlay
    case rally
    case net
    case mental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serve: return "Serve"
        case .returnPlay: return "Return"
        case .rally: return "Rally"
        case .net: return "Net Play"
        case .mental: return "Mental"
        }
    }
}

enum QuizDifficulty: String, Codable {
    case easy
    case medium
}

struct QuizQuestion: Identifiable, Codable, Hashable {
    let id: String
    let category: QuizCategory
    let difficulty: QuizDifficulty
    let focusTag: String
    let scenario: String
    let options: [String]
    let correctAnswerIndex: Int
    let explanation: String
    let takeaway: String
    let mistakeType: String
}

struct Quiz: Identifiable, Codable {
    let id: String
    let title: String
    let questions: [QuizQuestion]
}

struct TrainingTip: Identifiable, Codable, Hashable {
    let id: String
    let theme: String
    let advice: String
    let category: QuizCategory?
}

extension Quiz {
    var focusLabel: String {
        let categoryCounts = Dictionary(grouping: questions, by: \.[category])
            .mapValues { $0.count }
        return categoryCounts.max { $0.value < $1.value }?.key.title ?? questions.first?.category.title ?? "Match Play"
    }

    var primaryFocusTag: String? {
        questions.first?.focusTag
    }

    static let sample = dailyQuiz(for: Date())

    static func dailyTrainingTip(for date: Date = Date()) -> TrainingTip {
        let index = dayIndex(for: date) % dailyTrainingTips.count
        return dailyTrainingTips[index]
    }

    static func dailyQuiz(for date: Date = Date()) -> Quiz {
        let all = dailyQuestionBank
        let count = min(5, all.count)
        guard count > 0 else {
            return Quiz(id: "today", title: "Today’s CourtIQ", questions: [])
        }

        let start = dayIndex(for: date) % all.count
        let questions = (0..<count).map { all[(start + $0) % all.count] }

        return Quiz(
            id: "daily-\(dateKey(from: date))",
            title: "Today’s CourtIQ",
            questions: questions
        )
    }

    static func practiceQuiz(category: QuizCategory) -> Quiz {
        let categoryQuestions = dailyQuestionBank.filter { $0.category == category }
        let questions = Array(categoryQuestions.prefix(5))
        return Quiz(
            id: "practice-\(category.rawValue)",
            title: "\(category.title) Practice",
            questions: questions
        )
    }

    private static func dateKey(from date: Date) -> String {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return dateFormatter.string(from: startOfDay)
    }

    private static func dayIndex(for date: Date) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return Int(startOfDay.timeIntervalSince1970 / 86_400)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension Quiz {
    static let dailyQuestionBank: [QuizQuestion] = [
        QuizQuestion(
            id: "serve_001",
            category: .serve,
            difficulty: .medium,
            focusTag: "second serve pressure",
            scenario: "4-2 on your serve, your first serve has been inconsistent and you need a second serve that stays in.",
            options: ["Use a higher-margin spin serve to the body", "Hit a flat serve down the T", "Try a wide slice serve"],
            correctAnswerIndex: 0,
            explanation: "A higher-margin spin serve lowers the risk of a double fault while still giving attack options.",
            takeaway: "Protect the second serve under pressure.",
            mistakeType: "forcing the second serve"
        ),
        QuizQuestion(
            id: "serve_002",
            category: .serve,
            difficulty: .easy,
            focusTag: "serve variation",
            scenario: "Your opponent has adjusted to your wide serve on the deuce side 30-30 in the fourth game. What should you do?",
            options: ["Change to a serve down the T", "Keep serving wide", "Serve into the body"],
            correctAnswerIndex: 0,
            explanation: "Changing to the T forces the opponent to move in a different direction and can create a weaker return.",
            takeaway: "Vary your serve when the opponent learns your pattern.",
            mistakeType: "being predictable"
        ),
        QuizQuestion(
            id: "serve_003",
            category: .serve,
            difficulty: .medium,
            focusTag: "serve placement",
            scenario: "Your opponent's backhand is weaker than the forehand, and they stand slightly inside the baseline 5-4 in the first set.",
            options: ["Aim for the backhand with a T serve", "Serve wide to the forehand", "Serve into the body"],
            correctAnswerIndex: 0,
            explanation: "Targeting the weaker backhand helps you force a weaker reply or a short return.",
            takeaway: "Use serve placement to attack the weaker side.",
            mistakeType: "serving into strength"
        ),
        QuizQuestion(
            id: "serve_004",
            category: .serve,
            difficulty: .easy,
            focusTag: "safe serve",
            scenario: "You are on the verge of holding serve and need a safe first point 3-3 in a tight set.",
            options: ["Choose a reliable serve with margin", "Try to ace the opponent", "Serve a fast wide serve"],
            correctAnswerIndex: 0,
            explanation: "A reliable serve is better than a risky one when you need to close out a game.",
            takeaway: "Favor consistency when protecting serve.",
            mistakeType: "overaggressive serving"
        ),
        QuizQuestion(
            id: "serve_005",
            category: .serve,
            difficulty: .medium,
            focusTag: "body serve",
            scenario: "The opponent has been stepping in to return your wide serves before a key tiebreak. What is the smarter choice?",
            options: ["Serve to the body", "Keep serving wide", "Try a lower percentage T serve"],
            correctAnswerIndex: 0,
            explanation: "A body serve limits the returner's ability to attack and can win the point outright.",
            takeaway: "Use the body serve when the opponent is anticipating wide.",
            mistakeType: "ignoring returner positioning"
        ),
        QuizQuestion(
            id: "serve_006",
            category: .serve,
            difficulty: .medium,
            focusTag: "second serve pressure",
            scenario: "at 15-30 in the second set, your first serve has been inconsistent and you need a second serve that stays in.",
            options: ["Use a higher-margin spin serve to the body", "Hit a flat serve down the T", "Try a wide slice serve"],
            correctAnswerIndex: 0,
            explanation: "A higher-margin spin serve lowers the risk of a double fault while still giving attack options.",
            takeaway: "Protect the second serve under pressure.",
            mistakeType: "forcing the second serve"
        ),
        QuizQuestion(
            id: "serve_007",
            category: .serve,
            difficulty: .easy,
            focusTag: "serve variation",
            scenario: "Your opponent has adjusted to your wide serve on the deuce side during a pressure service game. What should you do?",
            options: ["Change to a serve down the T", "Keep serving wide", "Serve into the body"],
            correctAnswerIndex: 0,
            explanation: "Changing to the T forces the opponent to move in a different direction and can create a weaker return.",
            takeaway: "Vary your serve when the opponent learns your pattern.",
            mistakeType: "being predictable"
        ),
        QuizQuestion(
            id: "serve_008",
            category: .serve,
            difficulty: .medium,
            focusTag: "serve placement",
            scenario: "Your opponent's backhand is weaker than the forehand, and they stand slightly inside the baseline as the match reaches deuce.",
            options: ["Aim for the backhand with a T serve", "Serve wide to the forehand", "Serve into the body"],
            correctAnswerIndex: 0,
            explanation: "Targeting the weaker backhand helps you force a weaker reply or a short return.",
            takeaway: "Use serve placement to attack the weaker side.",
            mistakeType: "serving into strength"
        ),
        QuizQuestion(
            id: "serve_009",
            category: .serve,
            difficulty: .easy,
            focusTag: "safe serve",
            scenario: "You are on the verge of holding serve and need a safe first point up one break in the set.",
            options: ["Choose a reliable serve with margin", "Try to ace the opponent", "Serve a fast wide serve"],
            correctAnswerIndex: 0,
            explanation: "A reliable serve is better than a risky one when you need to close out a game.",
            takeaway: "Favor consistency when protecting serve.",
            mistakeType: "overaggressive serving"
        ),
        QuizQuestion(
            id: "serve_010",
            category: .serve,
            difficulty: .medium,
            focusTag: "body serve",
            scenario: "The opponent has been stepping in to return your wide serves at 1-1 in the deciding set. What is the smarter choice?",
            options: ["Serve to the body", "Keep serving wide", "Try a lower percentage T serve"],
            correctAnswerIndex: 0,
            explanation: "A body serve limits the returner's ability to attack and can win the point outright.",
            takeaway: "Use the body serve when the opponent is anticipating wide.",
            mistakeType: "ignoring returner positioning"
        ),
        QuizQuestion(
            id: "serve_011",
            category: .serve,
            difficulty: .medium,
            focusTag: "second serve pressure",
            scenario: "after losing the previous game, your first serve has been inconsistent and you need a second serve that stays in.",
            options: ["Use a higher-margin spin serve to the body", "Hit a flat serve down the T", "Try a wide slice serve"],
            correctAnswerIndex: 0,
            explanation: "A higher-margin spin serve lowers the risk of a double fault while still giving attack options.",
            takeaway: "Protect the second serve under pressure.",
            mistakeType: "forcing the second serve"
        ),
        QuizQuestion(
            id: "serve_012",
            category: .serve,
            difficulty: .easy,
            focusTag: "serve variation",
            scenario: "Your opponent has adjusted to your wide serve on the deuce side with the crowd on their feet. What should you do?",
            options: ["Change to a serve down the T", "Keep serving wide", "Serve into the body"],
            correctAnswerIndex: 0,
            explanation: "Changing to the T forces the opponent to move in a different direction and can create a weaker return.",
            takeaway: "Vary your serve when the opponent learns your pattern.",
            mistakeType: "being predictable"
        ),
        QuizQuestion(
            id: "serve_013",
            category: .serve,
            difficulty: .medium,
            focusTag: "serve placement",
            scenario: "Your opponent's backhand is weaker than the forehand, and they stand slightly inside the baseline in a long twilight session.",
            options: ["Aim for the backhand with a T serve", "Serve wide to the forehand", "Serve into the body"],
            correctAnswerIndex: 0,
            explanation: "Targeting the weaker backhand helps you force a weaker reply or a short return.",
            takeaway: "Use serve placement to attack the weaker side.",
            mistakeType: "serving into strength"
        ),
        QuizQuestion(
            id: "serve_014",
            category: .serve,
            difficulty: .easy,
            focusTag: "safe serve",
            scenario: "You are on the verge of holding serve and need a safe first point while the opponent is returning well.",
            options: ["Choose a reliable serve with margin", "Try to ace the opponent", "Serve a fast wide serve"],
            correctAnswerIndex: 0,
            explanation: "A reliable serve is better than a risky one when you need to close out a game.",
            takeaway: "Favor consistency when protecting serve.",
            mistakeType: "overaggressive serving"
        ),
        QuizQuestion(
            id: "serve_015",
            category: .serve,
            difficulty: .medium,
            focusTag: "body serve",
            scenario: "The opponent has been stepping in to return your wide serves with a chance to break. What is the smarter choice?",
            options: ["Serve to the body", "Keep serving wide", "Try a lower percentage T serve"],
            correctAnswerIndex: 0,
            explanation: "A body serve limits the returner's ability to attack and can win the point outright.",
            takeaway: "Use the body serve when the opponent is anticipating wide.",
            mistakeType: "ignoring returner positioning"
        ),
        QuizQuestion(
            id: "serve_016",
            category: .serve,
            difficulty: .medium,
            focusTag: "second serve pressure",
            scenario: "after a long baseline rally, your first serve has been inconsistent and you need a second serve that stays in.",
            options: ["Use a higher-margin spin serve to the body", "Hit a flat serve down the T", "Try a wide slice serve"],
            correctAnswerIndex: 0,
            explanation: "A higher-margin spin serve lowers the risk of a double fault while still giving attack options.",
            takeaway: "Protect the second serve under pressure.",
            mistakeType: "forcing the second serve"
        ),
        QuizQuestion(
            id: "serve_017",
            category: .serve,
            difficulty: .easy,
            focusTag: "serve variation",
            scenario: "Your opponent has adjusted to your wide serve on the deuce side when the wind is slight. What should you do?",
            options: ["Change to a serve down the T", "Keep serving wide", "Serve into the body"],
            correctAnswerIndex: 0,
            explanation: "Changing to the T forces the opponent to move in a different direction and can create a weaker return.",
            takeaway: "Vary your serve when the opponent learns your pattern.",
            mistakeType: "being predictable"
        ),
        QuizQuestion(
            id: "serve_018",
            category: .serve,
            difficulty: .medium,
            focusTag: "serve placement",
            scenario: "Your opponent's backhand is weaker than the forehand, and they stand slightly inside the baseline at the start of the final set.",
            options: ["Aim for the backhand with a T serve", "Serve wide to the forehand", "Serve into the body"],
            correctAnswerIndex: 0,
            explanation: "Targeting the weaker backhand helps you force a weaker reply or a short return.",
            takeaway: "Use serve placement to attack the weaker side.",
            mistakeType: "serving into strength"
        ),
        QuizQuestion(
            id: "serve_019",
            category: .serve,
            difficulty: .easy,
            focusTag: "safe serve",
            scenario: "You are on the verge of holding serve and need a safe first point as the opponent steps in.",
            options: ["Choose a reliable serve with margin", "Try to ace the opponent", "Serve a fast wide serve"],
            correctAnswerIndex: 0,
            explanation: "A reliable serve is better than a risky one when you need to close out a game.",
            takeaway: "Favor consistency when protecting serve.",
            mistakeType: "overaggressive serving"
        ),
        QuizQuestion(
            id: "serve_020",
            category: .serve,
            difficulty: .medium,
            focusTag: "body serve",
            scenario: "The opponent has been stepping in to return your wide serves before the biggest game of the set. What is the smarter choice?",
            options: ["Serve to the body", "Keep serving wide", "Try a lower percentage T serve"],
            correctAnswerIndex: 0,
            explanation: "A body serve limits the returner's ability to attack and can win the point outright.",
            takeaway: "Use the body serve when the opponent is anticipating wide.",
            mistakeType: "ignoring returner positioning"
        ),
        QuizQuestion(
            id: "return_001",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "attack weak second serve",
            scenario: "Your opponent hits a weak second serve to your forehand 30-40 in the third game. What is the best return?",
            options: ["Step in and hit a deep return", "Block it back with slice", "Try a down-the-line winner"],
            correctAnswerIndex: 0,
            explanation: "A deep return on a weak second serve takes control of the point without unnecessary risk.",
            takeaway: "Use weak seconds to take command.",
            mistakeType: "waiting too long"
        ),
        QuizQuestion(
            id: "return_002",
            category: .returnPlay,
            difficulty: .medium,
            focusTag: "return safe",
            scenario: "It's break point and the opponent serves fast to your forehand break point in the second set.",
            options: ["Return crosscourt safely", "Try a winner down the line", "Return to the body"],
            correctAnswerIndex: 0,
            explanation: "A safe crosscourt return keeps the point alive and protects against the score.",
            takeaway: "Play steady returns under pressure.",
            mistakeType: "overreaching"
        ),
        QuizQuestion(
            id: "return_003",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "body return",
            scenario: "The opponent serves into your body on the deuce side 15-30 after a long rally.",
            options: ["Return to their backhand", "Swing at your forehand", "Block it short"],
            correctAnswerIndex: 0,
            explanation: "Returning to the opponent's backhand is safer and often more effective against a body serve.",
            takeaway: "Use the opponent's body as a target.",
            mistakeType: "setting up their strength"
        ),
        QuizQuestion(
            id: "return_004",
            category: .returnPlay,
            difficulty: .medium,
            focusTag: "return recovery",
            scenario: "Your opponent serves wide to your backhand and you are stretched deuce in the seventh game.",
            options: ["Hit a safe crosscourt return", "Return down the line", "Slice it short"],
            correctAnswerIndex: 0,
            explanation: "A crosscourt return gives you time to recover and keeps the ball in play.",
            takeaway: "Think recovery when returning from wide.",
            mistakeType: "overextending"
        ),
        QuizQuestion(
            id: "return_005",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "return variation",
            scenario: "The opponent has returned your wide serves well for the past two points after your opponent has taken momentum.",
            options: ["Change to a down-the-line return", "Keep returning wide", "Return to the body"],
            correctAnswerIndex: 0,
            explanation: "Changing direction can disrupt the server's rhythm when a pattern is established.",
            takeaway: "Vary your return when the server adapts.",
            mistakeType: "following the same path"
        ),
        QuizQuestion(
            id: "return_006",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "attack weak second serve",
            scenario: "Your opponent hits a weak second serve to your forehand at 0-30 in the fifth game. What is the best return?",
            options: ["Step in and hit a deep return", "Block it back with slice", "Try a down-the-line winner"],
            correctAnswerIndex: 0,
            explanation: "A deep return on a weak second serve takes control of the point without unnecessary risk.",
            takeaway: "Use weak seconds to take command.",
            mistakeType: "waiting too long"
        ),
        QuizQuestion(
            id: "return_007",
            category: .returnPlay,
            difficulty: .medium,
            focusTag: "return safe",
            scenario: "It's break point and the opponent serves fast to your forehand during a key return game.",
            options: ["Return crosscourt safely", "Try a winner down the line", "Return to the body"],
            correctAnswerIndex: 0,
            explanation: "A safe crosscourt return keeps the point alive and protects against the score.",
            takeaway: "Play steady returns under pressure.",
            mistakeType: "overreaching"
        ),
        QuizQuestion(
            id: "return_008",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "body return",
            scenario: "The opponent serves into your body on the deuce side with your back against the wall.",
            options: ["Return to their backhand", "Swing at your forehand", "Block it short"],
            correctAnswerIndex: 0,
            explanation: "Returning to the opponent's backhand is safer and often more effective against a body serve.",
            takeaway: "Use the opponent's body as a target.",
            mistakeType: "setting up their strength"
        ),
        QuizQuestion(
            id: "return_009",
            category: .returnPlay,
            difficulty: .medium,
            focusTag: "return recovery",
            scenario: "Your opponent serves wide to your backhand and you are stretched after the opponent held serve easily.",
            options: ["Hit a safe crosscourt return", "Return down the line", "Slice it short"],
            correctAnswerIndex: 0,
            explanation: "A crosscourt return gives you time to recover and keeps the ball in play.",
            takeaway: "Think recovery when returning from wide.",
            mistakeType: "overextending"
        ),
        QuizQuestion(
            id: "return_010",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "return variation",
            scenario: "The opponent has returned your wide serves well for the past two points when the opponent's serve is improving.",
            options: ["Change to a down-the-line return", "Keep returning wide", "Return to the body"],
            correctAnswerIndex: 0,
            explanation: "Changing direction can disrupt the server's rhythm when a pattern is established.",
            takeaway: "Vary your return when the server adapts.",
            mistakeType: "following the same path"
        ),
        QuizQuestion(
            id: "return_011",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "attack weak second serve",
            scenario: "Your opponent hits a weak second serve to your forehand before a potential break. What is the best return?",
            options: ["Step in and hit a deep return", "Block it back with slice", "Try a down-the-line winner"],
            correctAnswerIndex: 0,
            explanation: "A deep return on a weak second serve takes control of the point without unnecessary risk.",
            takeaway: "Use weak seconds to take command.",
            mistakeType: "waiting too long"
        ),
        QuizQuestion(
            id: "return_012",
            category: .returnPlay,
            difficulty: .medium,
            focusTag: "return safe",
            scenario: "It's break point and the opponent serves fast to your forehand with the sun in your eyes.",
            options: ["Return crosscourt safely", "Try a winner down the line", "Return to the body"],
            correctAnswerIndex: 0,
            explanation: "A safe crosscourt return keeps the point alive and protects against the score.",
            takeaway: "Play steady returns under pressure.",
            mistakeType: "overreaching"
        ),
        QuizQuestion(
            id: "return_013",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "body return",
            scenario: "The opponent serves into your body on the deuce side as the court conditions slow down.",
            options: ["Return to their backhand", "Swing at your forehand", "Block it short"],
            correctAnswerIndex: 0,
            explanation: "Returning to the opponent's backhand is safer and often more effective against a body serve.",
            takeaway: "Use the opponent's body as a target.",
            mistakeType: "setting up their strength"
        ),
        QuizQuestion(
            id: "return_014",
            category: .returnPlay,
            difficulty: .medium,
            focusTag: "return recovery",
            scenario: "Your opponent serves wide to your backhand and you are stretched after a long rally.",
            options: ["Hit a safe crosscourt return", "Return down the line", "Slice it short"],
            correctAnswerIndex: 0,
            explanation: "A crosscourt return gives you time to recover and keeps the ball in play.",
            takeaway: "Think recovery when returning from wide.",
            mistakeType: "overextending"
        ),
        QuizQuestion(
            id: "return_015",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "return variation",
            scenario: "The opponent has returned your wide serves well for the past two points at 40-40 in a tight set.",
            options: ["Change to a down-the-line return", "Keep returning wide", "Return to the body"],
            correctAnswerIndex: 0,
            explanation: "Changing direction can disrupt the server's rhythm when a pattern is established.",
            takeaway: "Vary your return when the server adapts.",
            mistakeType: "following the same path"
        ),
        QuizQuestion(
            id: "return_016",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "attack weak second serve",
            scenario: "Your opponent hits a weak second serve to your forehand during a momentum shift. What is the best return?",
            options: ["Step in and hit a deep return", "Block it back with slice", "Try a down-the-line winner"],
            correctAnswerIndex: 0,
            explanation: "A deep return on a weak second serve takes control of the point without unnecessary risk.",
            takeaway: "Use weak seconds to take command.",
            mistakeType: "waiting too long"
        ),
        QuizQuestion(
            id: "return_017",
            category: .returnPlay,
            difficulty: .medium,
            focusTag: "return safe",
            scenario: "It's break point and the opponent serves fast to your forehand while the opponent is serving well.",
            options: ["Return crosscourt safely", "Try a winner down the line", "Return to the body"],
            correctAnswerIndex: 0,
            explanation: "A safe crosscourt return keeps the point alive and protects against the score.",
            takeaway: "Play steady returns under pressure.",
            mistakeType: "overreaching"
        ),
        QuizQuestion(
            id: "return_018",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "body return",
            scenario: "The opponent serves into your body on the deuce side in the first service game.",
            options: ["Return to their backhand", "Swing at your forehand", "Block it short"],
            correctAnswerIndex: 0,
            explanation: "Returning to the opponent's backhand is safer and often more effective against a body serve.",
            takeaway: "Use the opponent's body as a target.",
            mistakeType: "setting up their strength"
        ),
        QuizQuestion(
            id: "return_019",
            category: .returnPlay,
            difficulty: .medium,
            focusTag: "return recovery",
            scenario: "Your opponent serves wide to your backhand and you are stretched before the opponent's favorite pattern.",
            options: ["Hit a safe crosscourt return", "Return down the line", "Slice it short"],
            correctAnswerIndex: 0,
            explanation: "A crosscourt return gives you time to recover and keeps the ball in play.",
            takeaway: "Think recovery when returning from wide.",
            mistakeType: "overextending"
        ),
        QuizQuestion(
            id: "return_020",
            category: .returnPlay,
            difficulty: .easy,
            focusTag: "return variation",
            scenario: "The opponent has returned your wide serves well for the past two points when the score is tied.",
            options: ["Change to a down-the-line return", "Keep returning wide", "Return to the body"],
            correctAnswerIndex: 0,
            explanation: "Changing direction can disrupt the server's rhythm when a pattern is established.",
            takeaway: "Vary your return when the server adapts.",
            mistakeType: "following the same path"
        ),
        QuizQuestion(
            id: "rally_001",
            category: .rally,
            difficulty: .easy,
            focusTag: "crosscourt control",
            scenario: "Your opponent hits deep to your backhand 15-15 in the second set. What is the safest play?",
            options: ["Hit deep crosscourt", "Go down the line", "Drop it short"],
            correctAnswerIndex: 0,
            explanation: "A deep crosscourt shot keeps you in the rally and avoids risky angles.",
            takeaway: "Use the safer crosscourt path in rallies.",
            mistakeType: "forcing lines too early"
        ),
        QuizQuestion(
            id: "rally_002",
            category: .rally,
            difficulty: .medium,
            focusTag: "short ball attack",
            scenario: "You receive a short ball to your forehand 30-30 after a long point. What should you do?",
            options: ["Step in and attack", "Hit a safe slice", "Play a defensive lob"],
            correctAnswerIndex: 0,
            explanation: "Short balls are opportunities to take control, so attack when you can.",
            takeaway: "Use short balls to transition to offense.",
            mistakeType: "waiting too long"
        ),
        QuizQuestion(
            id: "rally_003",
            category: .rally,
            difficulty: .easy,
            focusTag: "recovery",
            scenario: "You are pulled wide and need to recover deuce in the first set.",
            options: ["Hit a crosscourt slice and recover", "Try a down-the-line winner", "Lob deep"],
            correctAnswerIndex: 0,
            explanation: "A slice keeps the ball in play and gives you time to recover your position.",
            takeaway: "Recover before trying to win.",
            mistakeType: "overhitting from awkward positions"
        ),
        QuizQuestion(
            id: "rally_004",
            category: .rally,
            difficulty: .medium,
            focusTag: "pace control",
            scenario: "The opponent is hitting flat and fast a crucial service game. How should you respond?",
            options: ["Use topspin to slow the pace", "Match the flat pace", "Hit harder"],
            correctAnswerIndex: 0,
            explanation: "Slowing the pace with topspin can disrupt an opponent who thrives on flat speed.",
            takeaway: "Change the pace to control the rally.",
            mistakeType: "letting them dictate rhythm"
        ),
        QuizQuestion(
            id: "rally_005",
            category: .rally,
            difficulty: .easy,
            focusTag: "direction change",
            scenario: "Your opponent is moving well laterally a momentum swing. What is the better shot?",
            options: ["Hit down the line", "Keep playing crosscourt", "Try a short angle"],
            correctAnswerIndex: 0,
            explanation: "Changing direction can take advantage of an opponent who expects crosscourt shots.",
            takeaway: "Use direction changes to destabilize your opponent.",
            mistakeType: "staying on the same path"
        ),
        QuizQuestion(
            id: "rally_006",
            category: .rally,
            difficulty: .easy,
            focusTag: "crosscourt control",
            scenario: "Your opponent hits deep to your backhand 30-40 in the third game. What is the safest play?",
            options: ["Hit deep crosscourt", "Go down the line", "Drop it short"],
            correctAnswerIndex: 0,
            explanation: "A deep crosscourt shot keeps you in the rally and avoids risky angles.",
            takeaway: "Use the safer crosscourt path in rallies.",
            mistakeType: "forcing lines too early"
        ),
        QuizQuestion(
            id: "rally_007",
            category: .rally,
            difficulty: .medium,
            focusTag: "short ball attack",
            scenario: "You receive a short ball to your forehand a long baseline exchange. What should you do?",
            options: ["Step in and attack", "Hit a safe slice", "Play a defensive lob"],
            correctAnswerIndex: 0,
            explanation: "Short balls are opportunities to take control, so attack when you can.",
            takeaway: "Use short balls to transition to offense.",
            mistakeType: "waiting too long"
        ),
        QuizQuestion(
            id: "rally_008",
            category: .rally,
            difficulty: .easy,
            focusTag: "recovery",
            scenario: "You are pulled wide and need to recover after a short change of direction.",
            options: ["Hit a crosscourt slice and recover", "Try a down-the-line winner", "Lob deep"],
            correctAnswerIndex: 0,
            explanation: "A slice keeps the ball in play and gives you time to recover your position.",
            takeaway: "Recover before trying to win.",
            mistakeType: "overhitting from awkward positions"
        ),
        QuizQuestion(
            id: "rally_009",
            category: .rally,
            difficulty: .medium,
            focusTag: "pace control",
            scenario: "The opponent is hitting flat and fast when the opponent is defending well. How should you respond?",
            options: ["Use topspin to slow the pace", "Match the flat pace", "Hit harder"],
            correctAnswerIndex: 0,
            explanation: "Slowing the pace with topspin can disrupt an opponent who thrives on flat speed.",
            takeaway: "Change the pace to control the rally.",
            mistakeType: "letting them dictate rhythm"
        ),
        QuizQuestion(
            id: "rally_010",
            category: .rally,
            difficulty: .easy,
            focusTag: "direction change",
            scenario: "Your opponent is moving well laterally at 4-4 in the second set. What is the better shot?",
            options: ["Hit down the line", "Keep playing crosscourt", "Try a short angle"],
            correctAnswerIndex: 0,
            explanation: "Changing direction can take advantage of an opponent who expects crosscourt shots.",
            takeaway: "Use direction changes to destabilize your opponent.",
            mistakeType: "staying on the same path"
        ),
        QuizQuestion(
            id: "rally_011",
            category: .rally,
            difficulty: .easy,
            focusTag: "crosscourt control",
            scenario: "Your opponent hits deep to your backhand with the crowd watching. What is the safest play?",
            options: ["Hit deep crosscourt", "Go down the line", "Drop it short"],
            correctAnswerIndex: 0,
            explanation: "A deep crosscourt shot keeps you in the rally and avoids risky angles.",
            takeaway: "Use the safer crosscourt path in rallies.",
            mistakeType: "forcing lines too early"
        ),
        QuizQuestion(
            id: "rally_012",
            category: .rally,
            difficulty: .medium,
            focusTag: "short ball attack",
            scenario: "You receive a short ball to your forehand during a weather delay. What should you do?",
            options: ["Step in and attack", "Hit a safe slice", "Play a defensive lob"],
            correctAnswerIndex: 0,
            explanation: "Short balls are opportunities to take control, so attack when you can.",
            takeaway: "Use short balls to transition to offense.",
            mistakeType: "waiting too long"
        ),
        QuizQuestion(
            id: "rally_013",
            category: .rally,
            difficulty: .easy,
            focusTag: "recovery",
            scenario: "You are pulled wide and need to recover at the start of a fifth game.",
            options: ["Hit a crosscourt slice and recover", "Try a down-the-line winner", "Lob deep"],
            correctAnswerIndex: 0,
            explanation: "A slice keeps the ball in play and gives you time to recover your position.",
            takeaway: "Recover before trying to win.",
            mistakeType: "overhitting from awkward positions"
        ),
        QuizQuestion(
            id: "rally_014",
            category: .rally,
            difficulty: .medium,
            focusTag: "pace control",
            scenario: "The opponent is hitting flat and fast after a missed opportunity. How should you respond?",
            options: ["Use topspin to slow the pace", "Match the flat pace", "Hit harder"],
            correctAnswerIndex: 0,
            explanation: "Slowing the pace with topspin can disrupt an opponent who thrives on flat speed.",
            takeaway: "Change the pace to control the rally.",
            mistakeType: "letting them dictate rhythm"
        ),
        QuizQuestion(
            id: "rally_015",
            category: .rally,
            difficulty: .easy,
            focusTag: "direction change",
            scenario: "Your opponent is moving well laterally when the opponent is under pressure. What is the better shot?",
            options: ["Hit down the line", "Keep playing crosscourt", "Try a short angle"],
            correctAnswerIndex: 0,
            explanation: "Changing direction can take advantage of an opponent who expects crosscourt shots.",
            takeaway: "Use direction changes to destabilize your opponent.",
            mistakeType: "staying on the same path"
        ),
        QuizQuestion(
            id: "rally_016",
            category: .rally,
            difficulty: .easy,
            focusTag: "crosscourt control",
            scenario: "Your opponent hits deep to your backhand at the end of a long rally. What is the safest play?",
            options: ["Hit deep crosscourt", "Go down the line", "Drop it short"],
            correctAnswerIndex: 0,
            explanation: "A deep crosscourt shot keeps you in the rally and avoids risky angles.",
            takeaway: "Use the safer crosscourt path in rallies.",
            mistakeType: "forcing lines too early"
        ),
        QuizQuestion(
            id: "rally_017",
            category: .rally,
            difficulty: .medium,
            focusTag: "short ball attack",
            scenario: "You receive a short ball to your forehand as the opponent sets up for the next shot. What should you do?",
            options: ["Step in and attack", "Hit a safe slice", "Play a defensive lob"],
            correctAnswerIndex: 0,
            explanation: "Short balls are opportunities to take control, so attack when you can.",
            takeaway: "Use short balls to transition to offense.",
            mistakeType: "waiting too long"
        ),
        QuizQuestion(
            id: "rally_018",
            category: .rally,
            difficulty: .easy,
            focusTag: "recovery",
            scenario: "You are pulled wide and need to recover during a key service game.",
            options: ["Hit a crosscourt slice and recover", "Try a down-the-line winner", "Lob deep"],
            correctAnswerIndex: 0,
            explanation: "A slice keeps the ball in play and gives you time to recover your position.",
            takeaway: "Recover before trying to win.",
            mistakeType: "overhitting from awkward positions"
        ),
        QuizQuestion(
            id: "rally_019",
            category: .rally,
            difficulty: .medium,
            focusTag: "pace control",
            scenario: "The opponent is hitting flat and fast with the score level in the set. How should you respond?",
            options: ["Use topspin to slow the pace", "Match the flat pace", "Hit harder"],
            correctAnswerIndex: 0,
            explanation: "Slowing the pace with topspin can disrupt an opponent who thrives on flat speed.",
            takeaway: "Change the pace to control the rally.",
            mistakeType: "letting them dictate rhythm"
        ),
        QuizQuestion(
            id: "rally_020",
            category: .rally,
            difficulty: .easy,
            focusTag: "direction change",
            scenario: "Your opponent is moving well laterally when momentum is shifting. What is the better shot?",
            options: ["Hit down the line", "Keep playing crosscourt", "Try a short angle"],
            correctAnswerIndex: 0,
            explanation: "Changing direction can take advantage of an opponent who expects crosscourt shots.",
            takeaway: "Use direction changes to destabilize your opponent.",
            mistakeType: "staying on the same path"
        ),
        QuizQuestion(
            id: "net_001",
            category: .net,
            difficulty: .medium,
            focusTag: "approach judgment",
            scenario: "Your approach shot is short and you are at the net 30-30 on the second set.",
            options: ["Hold back and keep the point alive", "Attack the net anyway", "Hit a defensive lob"],
            correctAnswerIndex: 0,
            explanation: "A short approach shot at the net is usually not worth the risk unless the ball is truly short.",
            takeaway: "Approach only when the shot is strong.",
            mistakeType: "forcing the net"
        ),
        QuizQuestion(
            id: "net_002",
            category: .net,
            difficulty: .easy,
            focusTag: "overhead defense",
            scenario: "Your opponent lobs to a comfortable height while you are at the net 15-15 during a key game.",
            options: ["Let it bounce and hit an overhead", "Take it on the rise", "Run back and lob"],
            correctAnswerIndex: 0,
            explanation: "Letting the ball bounce gives you a more controlled and reliable overhead.",
            takeaway: "Take medium-height lobs after one bounce.",
            mistakeType: "rushing the overhead"
        ),
        QuizQuestion(
            id: "net_003",
            category: .net,
            difficulty: .easy,
            focusTag: "low volley",
            scenario: "Your opponent hits a low ball at your feet while you are at the net deuce in the fifth game.",
            options: ["Cut it back low and keep it in play", "Reach for a wide volley", "Lob it up"],
            correctAnswerIndex: 0,
            explanation: "A low cut volley is the safest response to a ball at your feet.",
            takeaway: "Use control on low net balls.",
            mistakeType: "attempting a risky angle"
        ),
        QuizQuestion(
            id: "net_004",
            category: .net,
            difficulty: .medium,
            focusTag: "net target",
            scenario: "Your opponent returns softly to your forehand at the net after your opponent's deep shot.",
            options: ["Punch the volley into the open court", "Block it back gently", "Lob it back"],
            correctAnswerIndex: 0,
            explanation: "A punch volley into the open court is usually the clearest way to finish a soft reply.",
            takeaway: "Finish soft net balls with authority.",
            mistakeType: "being too passive"
        ),
        QuizQuestion(
            id: "net_005",
            category: .net,
            difficulty: .easy,
            focusTag: "net patience",
            scenario: "You are at the net but the opponent's ball is not easy to finish during a momentum swing.",
            options: ["Play a safe controlled volley", "Go for a low-percentage winner", "Lob it back deep"],
            correctAnswerIndex: 0,
            explanation: "A safe controlled volley is the best choice when the finish is not clear.",
            takeaway: "Choose control at the net when unsure.",
            mistakeType: "overaggressive net play"
        ),
        QuizQuestion(
            id: "net_006",
            category: .net,
            difficulty: .medium,
            focusTag: "approach judgment",
            scenario: "Your approach shot is short and you are at the net while the opponent is approaching.",
            options: ["Hold back and keep the point alive", "Attack the net anyway", "Hit a defensive lob"],
            correctAnswerIndex: 0,
            explanation: "A short approach shot at the net is usually not worth the risk unless the ball is truly short.",
            takeaway: "Approach only when the shot is strong.",
            mistakeType: "forcing the net"
        ),
        QuizQuestion(
            id: "net_007",
            category: .net,
            difficulty: .easy,
            focusTag: "overhead defense",
            scenario: "Your opponent lobs to a comfortable height while you are at the net at the start of a new game.",
            options: ["Let it bounce and hit an overhead", "Take it on the rise", "Run back and lob"],
            correctAnswerIndex: 0,
            explanation: "Letting the ball bounce gives you a more controlled and reliable overhead.",
            takeaway: "Take medium-height lobs after one bounce.",
            mistakeType: "rushing the overhead"
        ),
        QuizQuestion(
            id: "net_008",
            category: .net,
            difficulty: .easy,
            focusTag: "low volley",
            scenario: "Your opponent hits a low ball at your feet while you are at the net after a baseline rally.",
            options: ["Cut it back low and keep it in play", "Reach for a wide volley", "Lob it up"],
            correctAnswerIndex: 0,
            explanation: "A low cut volley is the safest response to a ball at your feet.",
            takeaway: "Use control on low net balls.",
            mistakeType: "attempting a risky angle"
        ),
        QuizQuestion(
            id: "net_009",
            category: .net,
            difficulty: .medium,
            focusTag: "net target",
            scenario: "Your opponent returns softly to your forehand at the net when the court is slowing down.",
            options: ["Punch the volley into the open court", "Block it back gently", "Lob it back"],
            correctAnswerIndex: 0,
            explanation: "A punch volley into the open court is usually the clearest way to finish a soft reply.",
            takeaway: "Finish soft net balls with authority.",
            mistakeType: "being too passive"
        ),
        QuizQuestion(
            id: "net_010",
            category: .net,
            difficulty: .easy,
            focusTag: "net patience",
            scenario: "You are at the net but the opponent's ball is not easy to finish with the opponent on the defensive.",
            options: ["Play a safe controlled volley", "Go for a low-percentage winner", "Lob it back deep"],
            correctAnswerIndex: 0,
            explanation: "A safe controlled volley is the best choice when the finish is not clear.",
            takeaway: "Choose control at the net when unsure.",
            mistakeType: "overaggressive net play"
        ),
        QuizQuestion(
            id: "net_011",
            category: .net,
            difficulty: .medium,
            focusTag: "approach judgment",
            scenario: "Your approach shot is short and you are at the net during a critical service game.",
            options: ["Hold back and keep the point alive", "Attack the net anyway", "Hit a defensive lob"],
            correctAnswerIndex: 0,
            explanation: "A short approach shot at the net is usually not worth the risk unless the ball is truly short.",
            takeaway: "Approach only when the shot is strong.",
            mistakeType: "forcing the net"
        ),
        QuizQuestion(
            id: "net_012",
            category: .net,
            difficulty: .easy,
            focusTag: "overhead defense",
            scenario: "Your opponent lobs to a comfortable height while you are at the net as the opponent tries to chip it back.",
            options: ["Let it bounce and hit an overhead", "Take it on the rise", "Run back and lob"],
            correctAnswerIndex: 0,
            explanation: "Letting the ball bounce gives you a more controlled and reliable overhead.",
            takeaway: "Take medium-height lobs after one bounce.",
            mistakeType: "rushing the overhead"
        ),
        QuizQuestion(
            id: "net_013",
            category: .net,
            difficulty: .easy,
            focusTag: "low volley",
            scenario: "Your opponent hits a low ball at your feet while you are at the net when the opponent has recovery time.",
            options: ["Cut it back low and keep it in play", "Reach for a wide volley", "Lob it up"],
            correctAnswerIndex: 0,
            explanation: "A low cut volley is the safest response to a ball at your feet.",
            takeaway: "Use control on low net balls.",
            mistakeType: "attempting a risky angle"
        ),
        QuizQuestion(
            id: "net_014",
            category: .net,
            difficulty: .medium,
            focusTag: "net target",
            scenario: "Your opponent returns softly to your forehand at the net before a big return.",
            options: ["Punch the volley into the open court", "Block it back gently", "Lob it back"],
            correctAnswerIndex: 0,
            explanation: "A punch volley into the open court is usually the clearest way to finish a soft reply.",
            takeaway: "Finish soft net balls with authority.",
            mistakeType: "being too passive"
        ),
        QuizQuestion(
            id: "net_015",
            category: .net,
            difficulty: .easy,
            focusTag: "net patience",
            scenario: "You are at the net but the opponent's ball is not easy to finish as conditions become tricky.",
            options: ["Play a safe controlled volley", "Go for a low-percentage winner", "Lob it back deep"],
            correctAnswerIndex: 0,
            explanation: "A safe controlled volley is the best choice when the finish is not clear.",
            takeaway: "Choose control at the net when unsure.",
            mistakeType: "overaggressive net play"
        ),
        QuizQuestion(
            id: "net_016",
            category: .net,
            difficulty: .medium,
            focusTag: "approach judgment",
            scenario: "Your approach shot is short and you are at the net after your last approach was short.",
            options: ["Hold back and keep the point alive", "Attack the net anyway", "Hit a defensive lob"],
            correctAnswerIndex: 0,
            explanation: "A short approach shot at the net is usually not worth the risk unless the ball is truly short.",
            takeaway: "Approach only when the shot is strong.",
            mistakeType: "forcing the net"
        ),
        QuizQuestion(
            id: "net_017",
            category: .net,
            difficulty: .easy,
            focusTag: "overhead defense",
            scenario: "Your opponent lobs to a comfortable height while you are at the net at the end of a long point.",
            options: ["Let it bounce and hit an overhead", "Take it on the rise", "Run back and lob"],
            correctAnswerIndex: 0,
            explanation: "Letting the ball bounce gives you a more controlled and reliable overhead.",
            takeaway: "Take medium-height lobs after one bounce.",
            mistakeType: "rushing the overhead"
        ),
        QuizQuestion(
            id: "net_018",
            category: .net,
            difficulty: .easy,
            focusTag: "low volley",
            scenario: "Your opponent hits a low ball at your feet while you are at the net when you feel slightly out of position.",
            options: ["Cut it back low and keep it in play", "Reach for a wide volley", "Lob it up"],
            correctAnswerIndex: 0,
            explanation: "A low cut volley is the safest response to a ball at your feet.",
            takeaway: "Use control on low net balls.",
            mistakeType: "attempting a risky angle"
        ),
        QuizQuestion(
            id: "net_019",
            category: .net,
            difficulty: .medium,
            focusTag: "net target",
            scenario: "Your opponent returns softly to your forehand at the net during a tense exchange.",
            options: ["Punch the volley into the open court", "Block it back gently", "Lob it back"],
            correctAnswerIndex: 0,
            explanation: "A punch volley into the open court is usually the clearest way to finish a soft reply.",
            takeaway: "Finish soft net balls with authority.",
            mistakeType: "being too passive"
        ),
        QuizQuestion(
            id: "net_020",
            category: .net,
            difficulty: .easy,
            focusTag: "net patience",
            scenario: "You are at the net but the opponent's ball is not easy to finish as the opponent changes pace.",
            options: ["Play a safe controlled volley", "Go for a low-percentage winner", "Lob it back deep"],
            correctAnswerIndex: 0,
            explanation: "A safe controlled volley is the best choice when the finish is not clear.",
            takeaway: "Choose control at the net when unsure.",
            mistakeType: "overaggressive net play"
        ),
        QuizQuestion(
            id: "mental_001",
            category: .mental,
            difficulty: .easy,
            focusTag: "pre-point routine",
            scenario: "You are nervous before a big point deuce in the fourth game. What should you do?",
            options: ["Use your regular pre-point routine", "Rush the point to get it over with", "Think about the crowd"],
            correctAnswerIndex: 0,
            explanation: "A routine helps you stay calm and focused on the process.",
            takeaway: "Use routine to manage nerves.",
            mistakeType: "rushing under pressure"
        ),
        QuizQuestion(
            id: "mental_002",
            category: .mental,
            difficulty: .medium,
            focusTag: "reset",
            scenario: "You just lost a close game and the opponent is celebrating 30-30 after a tight set.",
            options: ["Reset to the next point", "Replay the last error in your head", "Try to hit the next shot harder"],
            correctAnswerIndex: 0,
            explanation: "Resetting quickly prevents frustration from affecting the next point.",
            takeaway: "Let go of the last point and move on.",
            mistakeType: "dwelling on mistakes"
        ),
        QuizQuestion(
            id: "mental_003",
            category: .mental,
            difficulty: .easy,
            focusTag: "lead protection",
            scenario: "You are ahead and the opponent is trying to force errors a break point in the second set.",
            options: ["Play safe, consistent tennis", "Try to finish every point fast", "Change your game plan completely"],
            correctAnswerIndex: 0,
            explanation: "Protecting a lead is usually about consistency, not heroics.",
            takeaway: "Choose stability when leading.",
            mistakeType: "overplaying with a lead"
        ),
        QuizQuestion(
            id: "mental_004",
            category: .mental,
            difficulty: .medium,
            focusTag: "one point at a time",
            scenario: "You are down a set but want to stay in the match one game after losing the previous one.",
            options: ["Focus on one point at a time", "Think about winning the match", "Try riskier shots to come back quickly"],
            correctAnswerIndex: 0,
            explanation: "One point at a time keeps you present and avoids overwhelm.",
            takeaway: "Stay present when chasing a comeback.",
            mistakeType: "playing too far ahead"
        ),
        QuizQuestion(
            id: "mental_005",
            category: .mental,
            difficulty: .easy,
            focusTag: "momentum control",
            scenario: "Your opponent is gaining momentum during a long match. What should you do?",
            options: ["Stick to your game plan", "Try a risky change of pace", "Start playing more aggressively"],
            correctAnswerIndex: 0,
            explanation: "Sticking to your plan is often the best way to stop an opponent's momentum.",
            takeaway: "Trust your process during swings.",
            mistakeType: "reacting emotionally"
        ),
        QuizQuestion(
            id: "mental_006",
            category: .mental,
            difficulty: .easy,
            focusTag: "pre-point routine",
            scenario: "You are nervous before a big point while your energy feels high. What should you do?",
            options: ["Use your regular pre-point routine", "Rush the point to get it over with", "Think about the crowd"],
            correctAnswerIndex: 0,
            explanation: "A routine helps you stay calm and focused on the process.",
            takeaway: "Use routine to manage nerves.",
            mistakeType: "rushing under pressure"
        ),
        QuizQuestion(
            id: "mental_007",
            category: .mental,
            difficulty: .medium,
            focusTag: "reset",
            scenario: "You just lost a close game and the opponent is celebrating after a bad line call.",
            options: ["Reset to the next point", "Replay the last error in your head", "Try to hit the next shot harder"],
            correctAnswerIndex: 0,
            explanation: "Resetting quickly prevents frustration from affecting the next point.",
            takeaway: "Let go of the last point and move on.",
            mistakeType: "dwelling on mistakes"
        ),
        QuizQuestion(
            id: "mental_008",
            category: .mental,
            difficulty: .easy,
            focusTag: "lead protection",
            scenario: "You are ahead and the opponent is trying to force errors when the opponent is gaining confidence.",
            options: ["Play safe, consistent tennis", "Try to finish every point fast", "Change your game plan completely"],
            correctAnswerIndex: 0,
            explanation: "Protecting a lead is usually about consistency, not heroics.",
            takeaway: "Choose stability when leading.",
            mistakeType: "overplaying with a lead"
        ),
        QuizQuestion(
            id: "mental_009",
            category: .mental,
            difficulty: .medium,
            focusTag: "one point at a time",
            scenario: "You are down a set but want to stay in the match before the biggest game of the set.",
            options: ["Focus on one point at a time", "Think about winning the match", "Try riskier shots to come back quickly"],
            correctAnswerIndex: 0,
            explanation: "One point at a time keeps you present and avoids overwhelm.",
            takeaway: "Stay present when chasing a comeback.",
            mistakeType: "playing too far ahead"
        ),
        QuizQuestion(
            id: "mental_010",
            category: .mental,
            difficulty: .easy,
            focusTag: "momentum control",
            scenario: "Your opponent is gaining momentum as the conditions become windy. What should you do?",
            options: ["Stick to your game plan", "Try a risky change of pace", "Start playing more aggressively"],
            correctAnswerIndex: 0,
            explanation: "Sticking to your plan is often the best way to stop an opponent's momentum.",
            takeaway: "Trust your process during swings.",
            mistakeType: "reacting emotionally"
        ),
        QuizQuestion(
            id: "mental_011",
            category: .mental,
            difficulty: .easy,
            focusTag: "pre-point routine",
            scenario: "You are nervous before a big point after you lost the last rally. What should you do?",
            options: ["Use your regular pre-point routine", "Rush the point to get it over with", "Think about the crowd"],
            correctAnswerIndex: 0,
            explanation: "A routine helps you stay calm and focused on the process.",
            takeaway: "Use routine to manage nerves.",
            mistakeType: "rushing under pressure"
        ),
        QuizQuestion(
            id: "mental_012",
            category: .mental,
            difficulty: .medium,
            focusTag: "reset",
            scenario: "You just lost a close game and the opponent is celebrating during a key mental battle.",
            options: ["Reset to the next point", "Replay the last error in your head", "Try to hit the next shot harder"],
            correctAnswerIndex: 0,
            explanation: "Resetting quickly prevents frustration from affecting the next point.",
            takeaway: "Let go of the last point and move on.",
            mistakeType: "dwelling on mistakes"
        ),
        QuizQuestion(
            id: "mental_013",
            category: .mental,
            difficulty: .easy,
            focusTag: "lead protection",
            scenario: "You are ahead and the opponent is trying to force errors when you need to stay composed.",
            options: ["Play safe, consistent tennis", "Try to finish every point fast", "Change your game plan completely"],
            correctAnswerIndex: 0,
            explanation: "Protecting a lead is usually about consistency, not heroics.",
            takeaway: "Choose stability when leading.",
            mistakeType: "overplaying with a lead"
        ),
        QuizQuestion(
            id: "mental_014",
            category: .mental,
            difficulty: .medium,
            focusTag: "one point at a time",
            scenario: "You are down a set but want to stay in the match at the start of the final set.",
            options: ["Focus on one point at a time", "Think about winning the match", "Try riskier shots to come back quickly"],
            correctAnswerIndex: 0,
            explanation: "One point at a time keeps you present and avoids overwhelm.",
            takeaway: "Stay present when chasing a comeback.",
            mistakeType: "playing too far ahead"
        ),
        QuizQuestion(
            id: "mental_015",
            category: .mental,
            difficulty: .easy,
            focusTag: "momentum control",
            scenario: "Your opponent is gaining momentum while the opponent is hitting strong shots. What should you do?",
            options: ["Stick to your game plan", "Try a risky change of pace", "Start playing more aggressively"],
            correctAnswerIndex: 0,
            explanation: "Sticking to your plan is often the best way to stop an opponent's momentum.",
            takeaway: "Trust your process during swings.",
            mistakeType: "reacting emotionally"
        ),
        QuizQuestion(
            id: "mental_016",
            category: .mental,
            difficulty: .easy,
            focusTag: "pre-point routine",
            scenario: "You are nervous before a big point after a double fault. What should you do?",
            options: ["Use your regular pre-point routine", "Rush the point to get it over with", "Think about the crowd"],
            correctAnswerIndex: 0,
            explanation: "A routine helps you stay calm and focused on the process.",
            takeaway: "Use routine to manage nerves.",
            mistakeType: "rushing under pressure"
        ),
        QuizQuestion(
            id: "mental_017",
            category: .mental,
            difficulty: .medium,
            focusTag: "reset",
            scenario: "You just lost a close game and the opponent is celebrating during a momentum swing.",
            options: ["Reset to the next point", "Replay the last error in your head", "Try to hit the next shot harder"],
            correctAnswerIndex: 0,
            explanation: "Resetting quickly prevents frustration from affecting the next point.",
            takeaway: "Let go of the last point and move on.",
            mistakeType: "dwelling on mistakes"
        ),
        QuizQuestion(
            id: "mental_018",
            category: .mental,
            difficulty: .easy,
            focusTag: "lead protection",
            scenario: "You are ahead and the opponent is trying to force errors when the scoreboard is tight.",
            options: ["Play safe, consistent tennis", "Try to finish every point fast", "Change your game plan completely"],
            correctAnswerIndex: 0,
            explanation: "Protecting a lead is usually about consistency, not heroics.",
            takeaway: "Choose stability when leading.",
            mistakeType: "overplaying with a lead"
        ),
        QuizQuestion(
            id: "mental_019",
            category: .mental,
            difficulty: .medium,
            focusTag: "one point at a time",
            scenario: "You are down a set but want to stay in the match before a crucial break opportunity.",
            options: ["Focus on one point at a time", "Think about winning the match", "Try riskier shots to come back quickly"],
            correctAnswerIndex: 0,
            explanation: "One point at a time keeps you present and avoids overwhelm.",
            takeaway: "Stay present when chasing a comeback.",
            mistakeType: "playing too far ahead"
        ),
        QuizQuestion(
            id: "mental_020",
            category: .mental,
            difficulty: .easy,
            focusTag: "momentum control",
            scenario: "Your opponent is gaining momentum after a long on-court battle. What should you do?",
            options: ["Stick to your game plan", "Try a risky change of pace", "Start playing more aggressively"],
            correctAnswerIndex: 0,
            explanation: "Sticking to your plan is often the best way to stop an opponent's momentum.",
            takeaway: "Trust your process during swings.",
            mistakeType: "reacting emotionally"
        )
    ]

    static let dailyTrainingTips: [TrainingTip] = [
        TrainingTip(
            id: "tip_001",
            theme: "Serve with purpose",
            advice: "Use serve placement to force weaker returns instead of trying to bomb every ball.",
            category: .serve
        ),
        TrainingTip(
            id: "tip_002",
            theme: "Return early",
            advice: "Step in on a second or predictable first serve to keep the opponent from taking charge.",
            category: .returnPlay
        ),
        TrainingTip(
            id: "tip_003",
            theme: "Rally depth",
            advice: "Keep the ball deep in prolonged rallies and let the opponent create the short opportunity.",
            category: .rally
        ),
        TrainingTip(
            id: "tip_004",
            theme: "Approach selectively",
            advice: "Approach the net only when the ball is short and you have a clear finishing angle.",
            category: .net
        ),
        TrainingTip(
            id: "tip_005",
            theme: "Routine reset",
            advice: "Use a simple pre-point routine to reset your mindset after a mistake.",
            category: .mental
        ),
        TrainingTip(
            id: "tip_006",
            theme: "Attack the short ball",
            advice: "Short replies are the best time to take the initiative and move forward.",
            category: .rally
        ),
        TrainingTip(
            id: "tip_007",
            theme: "Protect the lead",
            advice: "When you're ahead, choose higher-percentage shots and make your opponent earn the next point.",
            category: .mental
        ),
        TrainingTip(
            id: "tip_008",
            theme: "Change your pattern",
            advice: "If the opponent reads your serve or return, change your placement rather than keep repeating it.",
            category: nil
        ),
        TrainingTip(
            id: "tip_009",
            theme: "Stay low on defense",
            advice: "On defense, aim to keep the ball low and force your opponent to generate the pace.",
            category: .rally
        ),
        TrainingTip(
            id: "tip_010",
            theme: "Positive momentum",
            advice: "Focus on one point at a time to stop your opponent's momentum swings.",
            category: .mental
        )
    ]
}