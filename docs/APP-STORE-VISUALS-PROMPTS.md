# DropVolley — App Store screenshot visuals (AI image prompts)

Goal: match competitors' emotional pull (SevenSix/CoachNow/SwingVision use real,
cinematic tennis imagery *behind* the phone). We generate aspirational clay-court
photography in our brand palette, then composite a device mockup (real app screen)
+ a benefit headline on top.

## Pipeline
1. **Generate the 6 background images** in a photo AI (Gemini "Nano Banana" / Imagen 4 / Flux / Midjourney) using the prompts below.
2. **Capture the 6 real app screens** from the simulator (my job).
3. **Composite** each: AI background → clay color-grade + a dark scrim in the top third → device mockup with the real screen → bold headline (my job).

**Apple rule (2.3.3):** a screenshot must show the app in use. So the AI photo is the *background*; the real app UI (device mockup) must be the focus. This is exactly what the top competitors do — compliant, and far more emotional than a flat color.

**Honesty:** decorative marketing imagery is fine (like stock photos). No fake ratings/testimonials — that stays banned.

## The look (paste as a shared suffix on EVERY prompt)
> Cinematic athletic-brand sports photography. Warm terracotta clay tennis court, golden-hour side light, soft atmospheric haze, fine film grain. Color palette: warm clay terracotta, cream, deep ink-navy shadows, a hint of gold. Shallow depth of field, 50mm lens, editorial premium campaign mood, aspirational. Clean empty negative space in the upper third for a headline. Photorealistic, high detail. No text, no logos, no watermark, no brand marks. Vertical 9:16 portrait.

Tips: keep faces/hands away from close-up (AI mangles rackets + fingers) — favour **from-behind, silhouette, motion-blur, or environmental** shots. Generate 3-4 variants each, pick the cleanest.

## The 6 prompts (swing-led storyboard)

**1 · SWING (hero / cover) — "Film your swing. Get an AI score."**
> ✅ **DONE — asset chosen (9 Jul).** Manus-generated `~/Downloads/tennis_ai_shoulder_fix.png`
> (1664×2080, 4:5): clay-court forehand + gold AI pose-overlay, brand palette, clean left
> negative space. Already shipped in-app as the `SwingAnalyzeHero` asset (analyzing screen).
> For the 9:16 screenshot: re-generate/outpaint taller in Manus with the same prompt, or
> crop-extend the clay ground; then composite device mockup + headline per the pipeline.
> Fallback prompt if regenerating:
> A tennis player captured from behind and slightly to the side, mid-forehand, the racket blurred in fast motion, a small puff of clay dust rising off the court, powerful and dynamic, an elegant translucent overlay of thin luminous gold lines connecting the joints with small glowing nodes and a sweeping arc tracing the racket path, artful not clinical, no numbers, no UI panels. [+ shared look]

**2 · AI COACH — "Most apps track your score. We coach your game."**
> A tennis player resting courtside on the clay, sitting on a low bench with a towel and water bottle, looking down thoughtfully in a quiet moment of studying the game, seen from the side. [+ shared look]

**3 · MATCH IQ — "Sharpen your match IQ."**
> An empty clay tennis court seen from a high three-quarter angle at golden hour, long dramatic net shadows stretching across the surface, one tennis ball resting on a white line, calm and strategic. [+ shared look]

**4 · KNOW YOUR GAME — "Know your game."**
> Warm intimate close detail of a tennis player's forearm and wristband resting on a racket handle on the clay, soft morning light, personal and reflective, no face. [+ shared look]

**5 · WALL PRACTICE — "Practice against any wall."**
> A lone player practising against a warm weathered brick wall on an urban court at golden hour, captured mid-motion from behind, a tennis ball frozen in the air near the wall, gritty and determined. [+ shared look]

**6 · DOUBLES — "Smarter doubles, instantly."**
> Two tennis players seen from behind sharing a fist bump at the net on a clay court, warm backlight rim-lighting their silhouettes, camaraderie and trust. [+ shared look]

## Headlines (from APP-STORE-COPY.md)
1 Film your swing. Get an AI score. · 2 Most apps track your score. We coach your game. · 3 Sharpen your match IQ. · 4 Know your game. · 5 Practice against any wall. · 6 Smarter doubles, instantly.
Subtitle: AI swing & match IQ coach · Identity: for club and weekend players who want to out-think the game.
