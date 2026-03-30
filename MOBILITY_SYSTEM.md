# Mobility System

## Model

- `MobilityFlow` captures each flow with:
  - `id`
  - `title`
  - `duration`
  - `type` (`MobilityFlowType`)
  - `goal`
  - `focusAreas` (`MobilityFocusArea`)
  - `movements`
  - `instructions`
  - `coachingCues`
  - `whyItMatters`
- `MobilityMovement` describes individual movements in a sequence.
- `MobilityFlowType` includes:
  - `quickReset`
  - `dailyMobility`
  - `recovery`
- `MobilityFocusArea` includes:
  - `hips`
  - `hamstrings`
  - `thoracicRotation`
  - `shoulders`
  - `ankles`

## Flow categories

- Quick Reset flows: 5–8 minutes, designed for fast pre-match or between-set resets.
- Daily Mobility flows: 10–20 minutes, designed for consistent daily maintenance.
- Recovery flows: 20–30 minutes, designed for post-match and long-day recovery.

## Content location

- Model definitions and sample content live in `CourtIQ/Core/Models/MobilityFlow.swift`.
- The sample library currently includes 15 flows, five in each category.

## UI

- `MobilityLibraryView` presents the premium mobility library in grouped sections by flow type.
- `MobilityFlowDetailView` shows each flow’s goal, focus areas, sequence, instructions, coaching cues, and tennis-specific benefits.
- `ProfileView` contains a premium-facing entry point to the mobility library.

## Tennis-specific positioning

Each flow is written to answer:
- what it improves on court,
- why it matters for serve/groundstroke rotation,
- how it supports movement, stability, or recovery for tennis.

## Access

- Mobility content is modeled as premium content.
- The UI displays premium status and preview information without requiring a backend purchase.
