# Discussion Foundation

## Model

- `DiscussionThread` anchors each conversation to a quiz item, training plan, mobility flow, or premium insight.
- `DiscussionComment` now includes viewer-level state:
  - `viewerHasLiked`
  - `canEdit`
  - `canDelete`
- Likes and reports are stored as first-class backend records rather than device-only counters.

## Current behavior

- Free preview users can read community threads.
- Signed-in All Access users can create, edit, delete, like, unlike, and report comments.
- Thread and comment state is cached locally for launch speed, then refreshed from Supabase.
- Launch threads are seeded in the backend and can also be materialized from content metadata inside the app when needed.

## Moderation

- Reports are submitted to the backend for manual review.
- No in-app moderator tooling ships in v1; moderation runs through the admin/dashboard workflow.
