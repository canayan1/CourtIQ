# Discussion Foundation

## Model

- `DiscussionTargetType` defines the kinds of content that can host discussions:
  - `quizItem`
  - `trainingSession`
  - `mobilityFlow`
  - `premiumInsight`
- `ContentDiscussionThread` captures a discussion thread with:
  - `id`
  - `targetType`
  - `targetID`
  - `title`
  - `commentCount`
  - `lastUpdated`
- `DiscussionRepository` provides sample thread data and lookup methods.

## Supported targets

- Quiz item discussions are tied to individual question IDs.
- Training session discussions are tied to quiz sessions or daily training IDs.
- Mobility flow discussions are tied to mobility flow IDs.
- Premium insight discussions are tied to premium library concepts.

## UI state

- `QuizView` shows a discussion block on the result screen.
- `MobilityFlowDetailView` shows a discussion summary and a disabled "Join discussion" placeholder.
- `ProfileView` highlights that discussion threads are ready to link across product content.

## Future evolution

- Add thread list and comment models.
- Enable real discussion posting and moderation.
- Link discussion threads to quiz analytics, training sessions, and premium guidance.
- Keep the current model as the foundation for thread count, content tagging, and target-based discussion lookup.
