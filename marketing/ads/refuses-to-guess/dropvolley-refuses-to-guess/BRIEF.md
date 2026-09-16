---
workflow: product-launch-video
flow: automation
storyboard: no
message: "DropVolley's fuel log refuses to guess — and that is why you can trust it"
angle: "Open on the claim every nutrition app makes, then show ours declining to make it: no comparison until five rated sessions sit on each side, and a screen that says how many are left"
destination: instagram-reels
aspect: 9:16
resolution: 1080x1920
language: en
audience: "adult club & improving tennis players on Instagram; sceptical of fitness-app advice"
length: 20-25s
capture: none
---

## Intent

A 20–25s vertical ad for the nutrition feature shipped in DropVolley 1.3.
No website capture — the app is iOS-only and the design system below is the
brand. Sell, not show, but the proof is a real captured app screen: the
insight card that refuses to draw a conclusion.

The whole idea is a pattern interrupt. Every app in this category answers
instantly. Ours counts first and says so on screen. An app admitting it does
not know yet is the most persuasive thing we have, and it is true.

## What this ad may NOT say

Non-negotiable — these come from the app's own Terms §8.4 and the health
disclaimer every user accepts on first launch:

- No "eat this and play better". Not for any food, in any phrasing.
- No dietary advice, no calorie or macro numbers aimed at the viewer, no
  supplements.
- No claim the app tells you what to eat. It reports what **you** logged.
- No invented users, ratings, rankings or testimonials (App Review 2.3.1).
- The closing frame carries: "General information for healthy adults, not
  dietary advice."

## Script (on-screen copy — viewers watch muted, so the captions are the ad)

1. HOOK (0–3s), ink background, type only:
   "Every nutrition app tells you what to eat."
   Beat. Then, smaller, clay: "This one won't."

2. TURN (3–8s): the phrase "What works for you" rises as a section header
   over the cream ground, and four rating pills land one by one —
   Energy · Legs · Focus · Stomach. Sub-line: "You log the meal. You rate
   how you played."

3. PROOF (8–16s): the real app screen (`fuel-insights.png`) slides up inside
   a phone frame. Push in on the insight card. The line on it is highlighted
   as it reads:
   "About 7 more rated sessions until your first comparison. Each one needs
   at least 5 sessions on each side to mean anything."
   Overlay, clay: "It counts before it talks."

4. WHY (16–21s), ink ground:
   "Below that, the difference is noise."
   "A confident answer built on noise is worse than no answer."

5. CTA (21–25s), cream:
   "Tennis Journal — free in DropVolley."
   Wordmark. Small print: "General information for healthy adults, not
   dietary advice."

## Design system

App-native, from `AppPalette`:

- clay `#C65C31` · clay bright `#E4894F` · clay text `#964626`
- cream `#E9DECB` · parchment `#FCF7EE` · sand `#E1D1B8`
- ink `#1E2938` · ink soft `#4A4640` · moss `#6C8366`
- Type: SF Pro Display / -apple-system. Headlines heavy, tight tracking.
  Same treatment as the App Store frames and `reels-iq/reel.html`.

Motion is calm and typographic. No shake, no whip pans, no stock footage.
The one camera move is the push-in on the insight card in scene 3 — it is
the payoff, so it gets the only movement that matters.

## Assets

Real 1206×2622 simulator captures, already in the repo:

- `marketing/instagram/shots/fuel-insights.png` — the refusal (scene 3, hero)
- `marketing/instagram/shots/fuel-log.png` — the five-tap log
- `marketing/instagram/shots/journal-cal.png` — the calendar
- `marketing/instagram/shots/guide-sources.png` — the sourced guide

## Render

Local first. HeyGen cloud rendering is available via the CLI if a local
render is slow or the machine is busy.
