// The smallest QuizQuestion the challenge codec needs. TennisChallenge.swift
// only ever reads `.id` off the bank, so a real one would drag the whole quiz
// model and its loader into a command-line test for no gain.
struct QuizQuestion {
    let id: String
}
