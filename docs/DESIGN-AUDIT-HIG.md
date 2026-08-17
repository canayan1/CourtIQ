# Design audit — Apple HIG lens, "read less, find instantly"

*16 Aug 2026, build 1.0.4 (31). Method: headless captures of Home, Train,
Matches, Doubles, Coach, Daily IQ (intro/session/summary/placement), Swing
setup + code review. Goal per owner: minimal reading, instant orientation
("even I forget where things are"), immediate usability.*

Severity: 🔴 fix before ads · 🟠 fix this cycle · 🟡 polish.

**STATUS (16 Aug, same day): ALL FINDINGS APPLIED** — A1/A3 (Home=today),
A2 (one name: Tennis IQ / Swing), A4 (Train title only), B1 (no auto-sheet),
B2 (legacy score → tier badge), B3 (copy diet), B4 (one-line quota, ≤5-word
headline), B5 (single merged category list), B6 (kicker dropped). B7 resolved
as designed. Remaining: C1–C4 polish (tracked in #41 backlog). Verified via
sim captures; owner feedback round next.

## A. Root cause of "even I forget where things are" (IA)

**A1 🔴 Every feature has 2–3 doors.** Matches & Doubles are BOTH tabs and
Home rows; Swing is a Home tile AND a Train card; Coach is a tab AND a Home
hero; IQ is a hero AND a tile. HIG: the tab bar is the app's map — when Home
duplicates it, no path is ever "the" path, so no path gets memorized.
→ Direction: Home = *today* (IQ hero, streak, one coach entry, Recent).
Remove launcher rows/tiles from Home; discovery lives in tabs only.

**A2 🔴 One concept, three names.** Tennis IQ appears as "Tennis IQ" (tile),
"Daily IQ" (hero + screen), and hides inside Train as "Practice" (category
units). Swing appears as "Swing", "Swing Analysis", "AI Swing Analysis" (nav
title). HIG consistency: one concept = one name, everywhere.
→ Pick: **"Tennis IQ"** for the whole loop; **"Swing"** everywhere.

**A3 🟠 Home has ~7 competing blocks** (2 heroes + section header + 2 tiles +
3 rows + Recent). No single primary action. HIG: one obvious primary per
screen. With A1 applied this collapses naturally to 3 blocks.

**A4 🟠 Train tab is five worlds** (Swing, Practice, Recover, Programs,
Wall) with no ordering logic; its header spends 3 elements saying nothing
("IMPROVE" + "Train" + "Sharpen every part of your game" = marketing, not
orientation). → One-word title, cards only; consider merging Practice into
the IQ surface (it IS the IQ library).

## B. Screen-by-screen

**B1 Matches 🔴 — auto-opened explainer sheet.** First entry presents "How
match logging works": ~90 words across 4 paragraphs BEFORE the user sees the
screen. Direct violation of the read-less goal; HIG favors empty-state hints
over modal onboarding. → Kill the auto-sheet; empty state with one line
("Log your first match") + big CTA; keep the explainer behind a ⓘ.

**B2 Doubles 🔴 — legacy 87/100 score still renders.** Saved partner row
("Jordan · 87/100" green chip) shows the numeric score we removed in the
honesty fix — legacy records with `score` but no `tierRaw` fall back to the
number. → Map legacy scores to tiers at render (or migrate on load); never
show a number. (This is the same class of issue the tier work fixed.)

**B3 Doubles 🟡 — copy density.** "Link with your doubles partner to unlock
your compatibility report." (11 words) → "See how you two fit." The manual
row header "Just want a quick read? Add a partner manually" (8 words) →
"Add manually."

**B4 Coach 🟠 — empty screen, tiny action, duplicated banner.** Quota card
says the same thing twice ("refreshes at midnight" / "Resets at midnight
local time"). Headline is an 11-word sentence. With no chats, the primary
action is a small "+" in the corner. → Banner: one line ("Daily quota ·
resets 00:00"); empty state: centered big "Ask your coach" CTA; headline ≤5
words ("Your game, talked through").

**B5 Daily IQ 🟡 — two lists of the same six categories.** "Your court map"
(mastery bars) + "Skill path" (unit counts) double the vertical read. →
Merge into one list: bar + count + chevron per category.

**B6 Swing setup 🟠 — two decisions on one screen + stale kicker.** Stroke
picker AND path choice stack on one screen; "STEP 1 OF 2" no longer matches
the actual flow. The coach card shows a price for something not yet
buyable — honest, but ensure waitlist framing stays unmistakable ("COMING
SOON" chip is good; keep it).
→ Either: path choice first (two big cards, zero text), stroke second; or
drop the kicker and visually separate the two questions.

**B7 Home Recent 🟡 — RESOLVED as designed.** Cards already carry a
one-word kind label (bottom row; the audit capture had cut it off) and the
compact age ("5w") matches platform convention. No change.

## C. System-standard details (HIG)

- **C1 🟡 Custom circular back button** everywhere instead of the standard
  chevron — costs swipe-back affordance recognition; verify interactive
  pop gesture still works on every pushed screen.
- **C2 🟡 Photo-card text contrast** (Programs/Wall tiles) is borderline in
  spots; HIG minimum 4.5:1 — current scrims mostly pass but Programs' aerial
  shot is close.
- **C3 🟡 Accessibility backlog** (already tracked #41): decorative photos
  not `.accessibilityHidden`, ~19 icon-only buttons without labels, Dynamic
  Type at accessibility sizes overflows photo tiles.
- **C4 🟡 BETA badge** on Swing uses a custom capsule — fine, but the same
  visual (ink capsule) is used for score chips on the quiz court; two
  meanings, one costume.

## D. What already matches the goal (keep)

- Daily IQ intro after the 5-word pass: number-first, chips, one CTA.
- Choose-your-path storefront: two cards, two lines each.
- Animated court stories: information without words — the strongest
  "less reading" asset in the app; lean on it harder (B5/B6 screens could
  show, not tell).
- Calm motion tempo + Reduce Motion fallbacks.

## E. Suggested order (when fixes are green-lit)

1. B2 (honesty regression — ship with next build regardless)
2. A1+A3 Home de-duplication (biggest orientation win)
3. B1 Matches auto-sheet removal
4. A2 naming unification (strings only)
5. B4/B6 screen fixes · 6. B5/B7/C* polish
