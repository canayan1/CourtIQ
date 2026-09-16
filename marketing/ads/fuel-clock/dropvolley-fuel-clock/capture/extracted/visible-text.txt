---
workflow: product-launch-video
flow: automation
storyboard: no
message: "Tennis has a fuel clock, and it is keyed to the match, not to the gym"
angle: "Teach the match-day fuel clock itself — meal, snack, changeover, the hour mark — using only numbers that are in the shipped guide with their sources, and let the app be where that clock lives"
destination: instagram-reels
aspect: 9:16
resolution: 1080x1920
language: en
audience: "adult club & improving tennis players on Instagram"
length: 18-22s
capture: none
---

## Intent

Nutrition **for tennis players** — that is the whole positioning, and the
reel has to sound like it was made by someone who plays.

The first attempt at this reel argued about the app's method: that it will
not draw a conclusion under five rated sessions. True, and interesting to
us, and completely uninteresting to a club player scrolling at night. It
was an epistemology ad. This one is a tennis ad.

So the reel teaches the thing. A viewer who never installs should come away
knowing when to eat before a match and what to do at a changeover. That is
the brand: useful first. The app is where the clock lives, not the subject
of the ad.

## Why the clock is the right shape

Generic nutrition advice is keyed to "exercise". Tennis is not keyed to
exercise — it is keyed to **match moments**: the meal, the hour-out snack,
the changeover, the point where a match crosses an hour, the first half
hour after. Nobody outside tennis has a changeover. Building the piece on
the tennis clock is the one thing a general nutrition app cannot copy.

## Every number must come from the shipped guide

Non-negotiable. These are the four stops and their sources, all already in
`nutrition_guide.en.json`:

1. **2–4 hours before** — main meal built on carbohydrate. ITF player guide.
2. **1 hour out** — a banana, toast, or oatmeal. The USTA's dietitian puts
   it in the 60–90 minute window.
3. **Every changeover** — four to twelve swallows, to a plan and not to
   thirst. USTA heat guidance; ~2% of body weight down blunts your game.
4. **Past the first hour** — 30 to 60 g of carbohydrate an hour. The joint
   ACSM / Academy / Dietitians of Canada position stand.

No number that is not in that file. No calorie or macro target aimed at the
viewer. No supplements. No "eat this and play better".

## Script (on-screen copy — viewers watch muted, the captions are the ad)

1. HOOK (0–4s), ink: "Your forehand is fine." beat. "It's the third set."
   Then, clay: "Tennis has a fuel clock."

2. THE CLOCK (4–14s), cream: the four stops arrive one at a time, each as a
   time marker plus its instruction. The changeover stop is the one that
   holds longest — it is the most tennis-specific and the most ignored.

3. SOURCE + CTA (14–20s), cream: the guide screen, "Every line of it
   sourced — ITF, USTA, ACSM." then "Tennis Journal — free in DropVolley."
   with the wordmark, and the required disclaimer, landing EARLY and held.

## Design system

App-native `AppPalette`: clay `#C65C31`, clay bright `#E4894F`, cream
`#E9DECB`, parchment `#FCF7EE`, sand `#E1D1B8`, ink `#1E2938`, ink soft
`#4A4640`, moss `#6C8366`. SF Pro Display. Calm, typographic, no stock
footage, nothing bounces.

## Assets

`marketing/instagram/shots/guide-sources.png` — a real guide section with
the ITF, USTA and ACSM named inline in the body text. It is the proof that
the clock is sourced, so it appears at full legibility, not as texture.

## Render

Local. HeyGen cloud is available via the CLI if needed.
