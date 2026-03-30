# CourtIQ — Build Checklist

This version of CourtIQ is a local-first daily tennis decision trainer.
No Firebase, no auth, no network, no remote data.

## Changed files

- `CourtIQ/App/MainTabView.swift`
- `CourtIQ/App/TodayView.swift`
- `CourtIQ/App/PracticeView.swift`
- `CourtIQ/App/ProfileView.swift`
- `CourtIQ/Core/Models/Quiz.swift`
- `CourtIQ/Core/Models/DailyQuizManager.swift`
- `CourtIQ/Features/Quiz/QuizView.swift`
- `CourtIQ/Features/Quiz/QuizViewModel.swift`

## What changed

- Replaced the placeholder tab layout with a focused Today / Practice / Stats app.
- Added a local question bank with 20 club-level scenario questions.
- Implemented deterministic daily quiz selection based on the current date.
- Added local streak persistence using `UserDefaults`.
- Built a clean Today screen with focus label, streak indicator, and a strong start CTA.
- Improved the quiz experience with instant feedback, explanations, and a polished result screen.

## How to test the daily quiz flow

1. Open Xcode.
2. If the repo does not already include an Xcode project, create a new iOS App project and add the `CourtIQ/App`, `CourtIQ/Core`, and `CourtIQ/Features` source folders.
3. Select a simulator such as iPhone 16.
4. Build and run the app.
5. In the **Today** tab, tap **Start Today’s Quiz**.
6. Answer all 5 questions.
7. Confirm each answer shows right/wrong feedback and an explanation.
8. Finish the quiz and verify the final score, headline, and takeaway text appear.

## How to test streak logic

1. Complete the daily quiz in the **Today** tab.
2. Confirm the streak value increments.
3. Reopen the app or switch tabs and verify streak persists.
4. If you complete the quiz again on the same day, the streak should not increase again.

## Notes

- The app is intentionally simple and local-only.
- The daily quiz is deterministic: the same day always delivers the same questions.
- Practice tab lets you replay category-focused quizzes.
