#!/bin/bash
# Runs every clip in a directory through the duel pipeline and prints what each
# one produced. The point is not the metres — it is the refusals.
#
#   tools/duel-corpus.sh ~/Downloads /path/to/more/clips
#
# The pipeline's most important behaviour is declining to measure a clip it
# cannot measure, and that is exactly what a single happy-path clip never
# tests. Nine clips have been through it so far: one court shot from behind at
# ground level (full metres), a wall session on a marked court (depth only), a
# wall session, a handheld balcony pan, and five side-on broadcast clips from
# the 2018 Davis Cup Americas Zone tie (Wikimedia Commons, CC BY-SA 4.0) — the
# last six all correctly refused.
#
# Broadcast footage is a REFUSAL corpus and nothing more. It is shot side-on
# from a height nobody's phone reaches, it cuts and zooms, and the players are
# professionals. Tuning any threshold to make it work would tune the pipeline
# for a shot no user will ever take — the same mistake as the first
# calibration run, which blamed the metrics for what was wrong with the clip.
set -u
BIN="${DUEL_BIN:-/tmp/duel-track}"
if [ ! -x "$BIN" ]; then
    echo "build it first, then set DUEL_BIN:"
    echo "  cp tools/duel-track.swift /tmp/main.swift"
    echo "  swiftc -O /tmp/main.swift tools/ClipReader.swift CourtIQ/Features/Duel/*.swift \\"
    echo "         CourtIQ/Features/SwingAnalysis/BallImpactAudio.swift -o /tmp/duel-track"
    exit 1
fi
for dir in "$@"; do
    find "$dir" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' \) \
    | sort | while read -r clip; do
        printf '%-46s ' "$(basename "$clip" | cut -c1-44)"
        "$BIN" "$clip" 2>&1 \
        | grep -E '^calibration|no court model|fall back|strokes$|only ever in pieces' \
        | tr '\n' ' '
        echo
    done
done
