#!/usr/bin/env node
// golden — deploy kapısı (docs/SWING-SYSTEM-DESIGN.md §5, INV-7).
// L1 (ücretsiz, her koşuda): dedektör kararlılığı + prompt lint + parser sözleşmesi.
// L2 (GEMINI anahtarı varsa): gerçek LLM çağrısı üstünde otomatik assert'ler —
//    VERIFIED doğruluğu, yasak sözlük, sayı-metin eşleşmesi, skor bandı.
// Kullanım: node golden.mjs [--l2] [--budget 1.0]   · Çıkış kodu ≠ 0 = KAPI KAPALI.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  buildSystemParts, systemPrompt, userPrompt,
  GENERATION_CONFIG, parseScoredAnalysis,
} from "../../supabase/functions/swing-analysis/prompts.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const G = JSON.parse(fs.readFileSync(path.join(HERE, "goldens.json"), "utf8"));
const expand = (p) => p.replace(/^~/, os.homedir());

let pass = 0, fail = 0;
const ok = (name, cond, detail = "") => {
  if (cond) { pass++; console.log(`  ✓ ${name}`); }
  else { fail++; console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ""}`); }
};

// ---------- L1.a dedektör kararlılığı (mine.py ham sayıları taban değerlere karşı) ----------
console.log("L1.a — ses dedektörü kararlılığı");
for (const [clip, baseline] of Object.entries(G.detectorBaselines)) {
  if (clip === "_") continue;
  const file = expand(`~/TennisVideos/instagram/${clip}`);
  if (!fs.existsSync(file)) { console.log(`  - atla (video yok): ${clip}`); continue; }
  const out = execFileSync("python3",
    [path.join(HERE, "../stroke-miner/mine.py"), "--video", file, "--label", "x", "--out", "/tmp/x", "--dry-run"],
    { encoding: "utf8" });
  const m = out.match(/→ (\d+) vuruş/);
  ok(`${clip}: ${m?.[1]} == ${baseline}`, m && Number(m[1]) === baseline, `çıktı: ${out.split("\n")[0]}`);
}

// ---------- L1.b prompt lint (INV-6 / F3) ----------
console.log("L1.b — prompt lint");
for (const [stroke, frags] of Object.entries(G.promptLint.requiredFragments)) {
  const p = systemPrompt(stroke, "right", 4);
  for (const lit of G.promptLint.forbiddenLiterals) {
    ok(`${stroke}: yasak şablon yok (${lit.slice(0, 24)}…)`, !p.includes(lit));
  }
  for (const f of frags) ok(`${stroke}: zorunlu kural var (${f.slice(0, 32)}…)`, p.includes(f));
}
{ // sayısız varyantta sayı sözü verilmiyor
  const p = systemPrompt("forehand", "right", null);
  ok("sayısız varyant sayıyı yasaklıyor", p.includes("Do NOT state how many reps"));
}
{ // R1 kare-yolu: userPrompt kare varyantı doğru kurulmuş
  const withFrames = userPrompt("forehand", 12);
  const videoPath = userPrompt("forehand");
  ok("kare varyantı kare sayısını + zaman etiketini anlatıyor",
     withFrames.includes("12 still frames") && withFrames.includes("labeled with its timestamp"));
  ok("video varyantı değişmedi", videoPath.startsWith("Coach my forehand groundstroke from this video"));
}

// ---------- L1.c parser sözleşmesi ----------
console.log("L1.c — parser sözleşmesi");
{
  const yes = parseScoredAnalysis("SCORE: 55\n\nVERIFIED: yes\ngövde");
  ok("yes → skor korunur + scaffold silinir", yes.score === 55 && !yes.mismatch && !yes.analysis.includes("VERIFIED"));
  const no = parseScoredAnalysis("SCORE: 68\n\nVERIFIED: no — looks like groundstrokes\nRe-check.");
  ok("no → mismatch + SKOR NULL + açıklama korunur", no.mismatch && no.score === null && no.analysis.includes("groundstrokes"));
  const legacy = parseScoredAnalysis("SCORE: 63\n\ndüz eski cevap");
  ok("eski format bozulmaz", legacy.score === 63 && !legacy.mismatch);
}

// ---------- L2 (anahtar varsa ve --l2 istendiyse) ----------
const wantL2 = process.argv.includes("--l2");
const envFile = path.join(HERE, ".env");
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+?)\s*$/);
    if (m && !(m[1] in process.env)) process.env[m[1]] = m[2];
  }
}
const KEY = process.env.GEMINI_VIDEO_API_KEY || process.env.GEMINI_API_KEY || "";
const MODEL = process.env.SWING_GEMINI_MODEL || "gemini-2.5-pro";

if (!wantL2) {
  console.log("L2 — atlandı (--l2 verilmedi; deploy öncesi --l2 ile koş)");
} else if (!KEY) {
  console.log("L2 — KOŞULAMADI: anahtar yok (tools/swing-bench/.env → GEMINI_VIDEO_API_KEY)");
  fail++; // deploy kapısında L2'siz yeşil YOK
} else {
  console.log(`L2 — gerçek LLM assert'leri (${MODEL})`);
  for (const c of G.llmCases) {
    const file = expand(c.clip);
    if (!fs.existsSync(file)) { console.log(`  - atla (video yok): ${c.id}`); continue; }
    const video = fs.readFileSync(file).toString("base64");
    const body = {
      systemInstruction: { parts: buildSystemParts(c.declared, "right", "", c.measuredCount) },
      contents: [{ role: "user", parts: [
        { inline_data: { mime_type: "video/quicktime", data: video }, video_metadata: { fps: 5 } },
        { text: userPrompt(c.declared) },
      ] }],
      generationConfig: GENERATION_CONFIG,
    };
    let raw;
    try {
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${KEY}`,
        { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body), signal: AbortSignal.timeout(240_000) });
      if (!resp.ok) { ok(`${c.id}: çağrı`, false, `HTTP ${resp.status}`); continue; }
      const data = await resp.json();
      raw = (data?.candidates?.[0]?.content?.parts ?? []).map((p) => p.text ?? "").join("\n");
    } catch (e) { ok(`${c.id}: çağrı`, false, String(e?.message ?? e).replaceAll(KEY, "[KEY]")); continue; }

    const firstLines = raw.split("\n").slice(0, 4).join("\n");
    const verdict = (firstLines.match(/VERIFIED:\s*(yes|no)/i)?.[1] ?? "yok").toLowerCase();
    const { analysis, score } = parseScoredAnalysis(raw);
    const lower = raw.toLowerCase();
    const e = c.expect;

    if (e.verified) ok(`${c.id}: VERIFIED=${e.verified}`, verdict === e.verified, `gerçek: ${verdict}`);
    if (e.verifiedAny) ok(`${c.id}: VERIFIED ∈ ${e.verifiedAny}`, e.verifiedAny.includes(verdict), `gerçek: ${verdict}`);
    if (e.scoreOmitted) ok(`${c.id}: skor yok`, score === null, `skor: ${score}`);
    if (e.scoreMax != null && score != null) ok(`${c.id}: skor ≤ ${e.scoreMax}`, score <= e.scoreMax, `skor: ${score}`);
    if (e.countInText != null) ok(`${c.id}: metinde ölçülen sayı (${e.countInText})`, analysis.includes(String(e.countInText)));
    if (e.noDigitsInOpening) ok(`${c.id}: açılışta sayı yok`, !/\b\d+\b/.test(analysis.split("\n")[0] ?? ""));
    if (e.resemblesMention) ok(`${c.id}: neye benzediği söyleniyor (${e.resemblesMention})`, lower.includes(e.resemblesMention));
    for (const w of e.forbidden ?? []) ok(`${c.id}: yasak sözlük yok ("${w}")`, !lower.includes(w.toLowerCase()));
  }
}

console.log(`\nGOLDEN: ${pass} geçti · ${fail} kaldı → ${fail === 0 ? "KAPI AÇIK ✅" : "KAPI KAPALI ⛔ (deploy yok)"}`);
process.exit(fail === 0 ? 0 : 1);
