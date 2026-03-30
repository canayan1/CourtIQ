import SwiftUI



struct QuizView: View {

    @StateObject private var vm: QuizViewModel

    let onComplete: () -> Void

    @State private var hasMarkedCompletion = false



    init(quiz: Quiz = .sample, onComplete: @escaping () -> Void = {}) {

        _vm = State(wrappedValue: QuizViewModel(quiz: quiz))

        self.onComplete = onComplete

    }



    var body: some View {

        Group {

            if vm.isFinished {

                resultScreen

            } else if let question = vm.currentQuestion {

                questionScreen(question)

            } else {

                Text("No questions available.")

                    .foregroundStyle(.secondary)

                    .padding()

            }

        }

        .navigationTitle(vm.quiz.title)

        .navigationBarTitleDisplayMode(.inline)

        .onChange(of: vm.isFinished) { finished in

            guard finished, !hasMarkedCompletion else { return }

            hasMarkedCompletion = true

            onComplete()

        }

    }



    private func questionScreen(_ question: QuizQuestion) -> some View {

        return ScrollView {

            VStack(alignment: .leading, spacing: 24) {

                ProgressView(value: vm.progress)

                    .tint(.green)



                Text("Q\(vm.currentIndex + 1) of \(vm.quiz.questions.count)")

                    .font(.caption)

                    .foregroundStyle(.secondary)



                Text(question.scenario)

                    .font(.body)

                    .lineSpacing(5)



                VStack(spacing: 12) {

                    ForEach(Array(question.options.enumerated()), id: \.0) { index, option in

                        optionButton(option, index: index, question: question)

                    }

                }



                if vm.isAnswered {

                    VStack(alignment: .leading, spacing: 12) {

                        Label("Explanation", systemImage: "info.circle.fill")

                            .font(.headline)

                        Text(question.explanation)

                            .font(.callout)

                            .lineSpacing(4)



                        Text("Tip: \(question.takeaway)")

                            .font(.subheadline)

                            .foregroundStyle(.secondary)



                        Text("Common mistake: \(question.mistakeType)")

                            .font(.subheadline)

                            .foregroundStyle(.secondary)

                    }

                    .padding()

                    .background(Color(.secondarySystemBackground))

                    .clipShape(RoundedRectangle(cornerRadius: 14))



                    Button("Next") {

                        vm.next()

                    }

                    .buttonStyle(PrimaryButtonStyle())

                }

            }

            .padding()

        }

    }



    private func optionButton(_ option: String, index: Int, question: QuizQuestion) -> some View {

        let isSelected = vm.selectedOptionIndex == index

        let isCorrect = index == question.correctAnswerIndex

        let revealed = vm.isAnswered



        let backgroundColor: Color = {

            if !revealed { return Color(.secondarySystemBackground) }

            if isCorrect { return .green.opacity(0.2) }

            if isSelected { return .red.opacity(0.2) }

            return Color(.secondarySystemBackground)

        }()



        return Button {

            vm.select(optionIndex: index)

        } label: {

            HStack(alignment: .top, spacing: 12) {

                Text(option)

                    .foregroundStyle(.primary)

                    .multilineTextAlignment(.leading)

                Spacer()

                if revealed {

                    if isCorrect {

                        Image(systemName: "checkmark.circle.fill")

                            .foregroundStyle(.green)

                            .font(.title3)

                    } else if isSelected {

                        Image(systemName: "xmark.circle.fill")

                            .foregroundStyle(.red)

                            .font(.title3)

                    }

                }

            }

            .padding()

            .background(backgroundColor)

            .clipShape(RoundedRectangle(cornerRadius: 14))

            .overlay(

                RoundedRectangle(cornerRadius: 14)

                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)

            )

        }

        .disabled(revealed)

    }



    private var resultScreen: some View {

        let tip = Quiz.dailyTrainingTip()

        return VStack(spacing: 24) {



            Spacer()



            Image(systemName: vm.score == vm.quiz.questions.count ? "trophy.fill" : "tennisball.fill")

                .font(.system(size: 72))

                .foregroundStyle(.yellow)



            VStack(spacing: 8) {

                Text(resultHeadline)

                    .font(.title.bold())

                Text("\(vm.score) of \(vm.quiz.questions.count) correct")

                    .font(.title2)

                    .foregroundStyle(.secondary)

            }



            Text(resultTakeaway)

                .multilineTextAlignment(.center)

                .foregroundStyle(.secondary)

                .padding(.horizontal)



            VStack(alignment: .leading, spacing: 12) {

                Label("Training Tip", systemImage: "lightbulb.fill")

                    .font(.headline)

                Text(tip.theme)

                    .font(.headline)

                Text(tip.advice)

                    .font(.subheadline)

                    .foregroundStyle(.secondary)

            }

            .padding()

            .background(Color(.secondarySystemBackground))

            .clipShape(RoundedRectangle(cornerRadius: 14))



            discussionBlock



            Spacer()



            Button("Review Today’s Quiz") {

                vm.restart()

                hasMarkedCompletion = false

            }

            .buttonStyle(PrimaryButtonStyle())

            .padding(.horizontal)

        }

        .padding()

    }



    private var resultHeadline: String {

        switch vm.score {

        case vm.quiz.questions.count:

            return "Decision sharp today"

        case vm.quiz.questions.count - 1:

            return "Strong day on court"

        case 1...:

            return "Good habits, keep building"

        default:

            return "Ready to train again tomorrow"

        }

    }



    private var resultTakeaway: String {

        switch vm.score {

        case vm.quiz.questions.count:

            return "You aligned your choices with smart club-level court play. Come back tomorrow for the next challenge."

        case vm.quiz.questions.count - 1:

            return "One more adjustment and your decision game is tighter. Keep the focus on court sense."

        case 1...:

            return "You found some strong options. Use tomorrow’s quiz to sharpen the next decision."

        default:

            return "Practice the decision process again tomorrow and build consistency one day at a time."

        }

    }



    private var discussionBlock: some View {

        let threadCount = DiscussionRepository.threadCount(for: .trainingSession, targetID: vm.quiz.id)



        return VStack(alignment: .leading, spacing: 12) {

            Text("Discussion")

                .font(.headline)

            if threadCount > 0 {

                Text("\(threadCount) discussion thread(s) are available for this session.")

                    .foregroundStyle(.secondary)

            } else {

                Text("Discussion foundation is ready for this session.")

                    .foregroundStyle(.secondary)

            }

            Button("Join discussion") {}

                .buttonStyle(.bordered)

                .disabled(true)

        }

        .padding()

        .background(Color(.secondarySystemBackground))

        .clipShape(RoundedRectangle(cornerRadius: 14))

    }

}



struct PrimaryButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {

        configuration.label

            .font(.headline)

            .frame(maxWidth: .infinity)

            .padding()

            .background(configuration.isPressed ? Color.green.opacity(0.8) : Color.green)

            .foregroundStyle(.white)

            .clipShape(RoundedRectangle(cornerRadius: 14))

            .scaleEffect(configuration.isPressed ? 0.97 : 1)

            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)

    }

}

