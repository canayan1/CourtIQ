# 5 Instagram Reels — HeyGen scripts

Format: 9:16, 1080×1920. Avatar talking head, captions burned in.
Length target 22–30s each (HeyGen avatars run ~2.5 words/sec).

Rules these scripts keep:
- No download counts, ratings, awards or testimonials we don't have.
- No implied link to Tennis Ireland, the ITF or WTN.
- Swing/form analysis is named as beta wherever it appears.
- **Reel 5 (coach review) is ON HOLD — do not shoot it.** It was written on
  26 Aug 2026 when the IAP was approved and purchasable. It is not any more:
  `com.canayan93.courtiq.coachreview1` is **Removed From Sale** as of the 1.3
  submission (16 Sep 2026), so the script advertises something nobody can
  buy. Re-check the product's state in App Store Connect before it is shot,
  and re-read the script against whatever is true then.

Per reel: **Script** goes in HeyGen's text box. **Captions** are the burned-in
overlays (HeyGen auto-captions, then fix the ones marked). **Cutaways** are
what to show over the avatar — use your own court footage or app screen
recordings, never stock with visible logos.

---

## 1. "Where do you serve?" — the wedge

**Hook (0–2s, on screen before the avatar speaks):**
`30–40 down. Where do you serve?`

**Script (~62 words):**
> Thirty–forty down. Where do you serve?
>
> Most club players go for the line, miss, and hand over the break. The
> percentage answer is the body serve — it jams the returner, kills the
> angle, and you don't need a first serve you don't have.
>
> That's the kind of thing DropVolley drills. Not your forehand. Your
> decisions. Link's in the bio, iOS for now.

**Captions to fix by hand:** `30–40`, `DropVolley`.

**Cutaways:**
- 0–3s: a serve from behind the baseline, no audio.
- 6–14s: the in-app scenario screen with the court diagram animating.
- 20s+: back to the avatar for the CTA.

**Caption (post text):**
> The point you lost at 30–40 wasn't a technique problem.
> DropVolley — decisions, not strokes. iOS.

---

## 2. The wall

**Hook (0–2s):**
`The wall never misses.`

**Script (~58 words):**
> The wall never misses. It's the highest-rep partner you'll ever get, and
> it's free.
>
> The problem is nobody counts. Twenty minutes against a wall feels like
> practice and produces nothing you can measure.
>
> DropVolley counts the reps for you and gives you structured wall sessions
> instead of aimless hitting. Solo practice that actually adds up.

**Cutaways:**
- 0–4s: ball off a wall, slow motion if you have it.
- 8–18s: the Wall screen mid-session with the count moving.

**Caption (post text):**
> Twenty minutes against a wall, counted.
> Solo practice that adds up. DropVolley, iOS.

---

## 3. Doubles — who covers the middle

**Hook (0–2s):**
`Both of you watched it land. Again.`

**Script (~65 words):**
> Ball goes down the middle. Both of you watch it land. Then you look at
> each other.
>
> The rule is simple: the middle belongs to whoever's forehand is closer to
> it, and it gets agreed before the point, not after.
>
> DropVolley has doubles scenarios that drill exactly these calls — court
> position, poaching, who takes what. Play them with your partner and stop
> having that look.

**Cutaways:**
- 0–4s: a doubles point where the middle drops.
- 10–20s: a 4-player doubles scenario animating in the app.

**Caption (post text):**
> The middle isn't nobody's. Sort it before the point.
> Doubles scenarios in DropVolley. iOS.

---

## 4. The match journal

**Hook (0–2s):**
`You know you lose to pushers. You don't know why.`

**Script (~60 words):**
> You already know you lose to pushers. What you don't know is why — which
> shot you rush, which score you tighten up at, which surface it happens on.
>
> That's not a memory problem, it's a record problem.
>
> Log your matches in DropVolley and the pattern shows up on its own. Then
> you can actually fix something specific.

**Cutaways:**
- 6–14s: logging a match in the app, then the trend view.

**Caption (post text):**
> "I always lose to pushers" is a feeling. The pattern is data.
> Match journal in DropVolley. iOS.

---

## 5. A real coach watches your swing — ⚠️ ON HOLD, DO NOT SHOOT

> The in-app purchase behind this reel is Removed From Sale (checked 16 Sep
> 2026 against the App Store Connect API). Everything below still describes
> the feature accurately, but shooting it now would advertise a purchase
> that cannot be completed. Left in place for when the product goes back on
> sale; check its state first.

**Hook (0–2s):**
`A person watches it. Not an algorithm.`

**Script (~66 words):**
> Film one swing. A qualified tennis coach watches it — an actual person,
> not an algorithm — and sends back a voice review, timestamped notes on
> what they saw, a five-point scorecard and one drill to take to your next
> session. Within seventy-two hours.
>
> There's AI form analysis in the app too, and it's useful, but it's beta
> and it isn't this.

**Captions to fix by hand:** `72 hours`, `5-point`.

**Cutaways:**
- 0–5s: filming a swing on a phone tripod.
- 10–20s: the delivered review screen — scorecard and the voice note.
- Keep the coach's face out of it. The reviewer is anonymous by design.

**Caption (post text):**
> One swing. A real coach watches it. 72 hours.
> DropVolley — iOS.

---

## Shooting notes

- **Same avatar and voice across all five.** Five different presenters reads
  as a content farm.
- **Subtitles always on.** Reels are watched muted; the hook has to land as
  text in the first 1.5 seconds.
- **One CTA, at the end, once.** "Link in bio, iOS for now." Don't repeat it.
- **No music with lyrics** under a talking head — it fights the voice.
- **Do not fake engagement.** No invented counts, no "as seen in", no
  screenshots of comments that don't exist.

## To have me generate these

HeyGen isn't reachable from this machine — no API key, no MCP. Drop a key at
`~/.appstore-keys/heygen_api_key.txt` (chmod 600, and it stays out of git)
and I can drive the v2 API end to end: pick avatar and voice, submit all
five, poll the jobs, download the MP4s to the Desktop.
