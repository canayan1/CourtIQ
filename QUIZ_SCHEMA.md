# CourtIQ Quiz Schema

## Question schema
Each quiz question is stored as a structured coaching scenario with fields that support decision guidance and training feedback.

- `id` (String)
  - Unique question identifier.
  - Format should be descriptive and consistent, e.g. `serve_012`, `rally_037`.

- `category` (`QuizCategory`)
  - One of: `serve`, `returnPlay`, `rally`, `net`, `mental`.
  - Used for category practice and focus tracking.

- `difficulty` (`QuizDifficulty`)
  - One of: `easy`, `medium`.
  - Represents decision complexity and commonness.

- `focusTag` (String)
  - One sentence tag describing the tactical focus.
  - Example: `second serve pressure`, `short ball attack`, `mental reset`.
  - Used to surface the quiz theme in results and training guidance.

- `scenario` (String)
  - Short realistic tennis scenario.
  - Should describe a court position, score context, or opponent behavior.
  - Avoid trivia, abstract statements, or generic sports language.

- `options` ([String])
  - Exactly three answer options.
  - Include at least one clear high-percentage choice and one high-risk option.
  - Avoid nearly identical choices.

- `correctAnswerIndex` (Int)
  - Index of the correct option in `options`.
  - Zero-based.

- `explanation` (String)
  - Immediate feedback after the answer.
  - Should explain why the correct choice is better and what it protects.
  - Keep it practical and concise.

- `takeaway` (String)
  - One coaching sentence reinforcing the learning.
  - Example: `Protect the point on second serve.`

- `mistakeType` (String)
  - One short phrase describing the common error.
  - Example: `being predictable`, `overforcing pace`, `ignoring positioning`.

## Writing rules
- Use real tennis court language: serve, return, baseline, net, short ball, body, crosscourt, down the line.
- Keep scenarios grounded in daily club-level play.
- Do not use mythic or professional-only terms.
- Every answer must map to a real training correction.
- Avoid yes/no or vague attitude options.
- Keep explanations concrete and connected to the scenario.
- Reserve `mental` questions for routine, reset, focus, momentum, or pressure patterns.

## Output files
- `CourtIQ/Core/Models/Quiz.swift` contains the production quiz bank.
- `QUESTION_BANK_100.json` should mirror the Swift model as JSON for content review and future tooling.
