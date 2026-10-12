// The clip question bank, shared by the clips functions.
//
// Source of truth is CourtIQ/Resources/Content/clip_questions.json; this file
// mirrors it so the server validates answers against the same ids the app
// shows. If the two drift, a vote the app allowed gets a 400 — loud, not
// silent. Keep it identical. (Q2 lists are provisional — CLIPS-SPEC §11.2.)

export const CLIP_QUESTIONS = {
  version: 1,
  strokes: ["forehand", "backhand", "serve", "volley"],
  q1: ["footwork", "technique", "decision", "unclear"],
  q2: {
    footwork: ["late_split", "no_adjust", "too_close", "no_recovery"],
    technique: ["late_prep", "racket_face", "contact_point", "wrist", "short_finish"],
    decision: ["wrong_target", "overhit", "no_height"],
    unclear: [],
  } as Record<string, string[]>,
  q3ToleranceMs: 300,
  q4: {
    wtn: { min: 1, max: 40, hitWithin: 3 },
    utr: { min: 1, max: 16.5, hitWithin: 0.75 },
    band: { values: ["2.5", "3.0", "3.5", "4.0", "4.5", "5.0+"], hitWithin: 1 },
  } as Record<string, { min?: number; max?: number; values?: string[]; hitWithin: number }>,
  minVotesForCrowd: 3,
  maxClipMs: 12_000,
};

export interface VoteInput {
  q1?: unknown; q2?: unknown; q3Ms?: unknown; q4?: unknown;
}

export interface CleanVote {
  q1: string; q2: string | null; q3Ms: number | null; q4: number | null;
}

/** Validates a vote against the bank. Returns a reason string on failure. */
export function cleanVote(v: VoteInput, durationMs: number): CleanVote | string {
  const q1 = typeof v.q1 === "string" ? v.q1 : "";
  if (!CLIP_QUESTIONS.q1.includes(q1)) return "bad_q1";

  let q2: string | null = null;
  if (q1 !== "unclear") {
    q2 = typeof v.q2 === "string" ? v.q2 : "";
    if (!CLIP_QUESTIONS.q2[q1].includes(q2)) return "bad_q2";
  }

  let q3Ms: number | null = null;
  if (q1 !== "unclear") {
    if (typeof v.q3Ms !== "number" || !Number.isFinite(v.q3Ms)) return "bad_q3";
    if (v.q3Ms < 0 || v.q3Ms > Math.max(durationMs, 1)) return "bad_q3";
    q3Ms = Math.round(v.q3Ms);
  }

  // q4 is optional everywhere; "I can't tell" is a legitimate answer to a level.
  let q4: number | null = null;
  if (v.q4 !== undefined && v.q4 !== null) {
    if (typeof v.q4 !== "number" || !Number.isFinite(v.q4)) return "bad_q4";
    q4 = v.q4;
  }
  return { q1, q2, q3Ms, q4 };
}
