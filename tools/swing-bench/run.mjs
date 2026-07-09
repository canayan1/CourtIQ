#!/usr/bin/env node
// swing-bench — Can'ın arşiv kliplerini PROD swing-analysis prompt'uyla (birebir —
// edge fonksiyonunun kendi modülünden import edilir) doğrudan Gemini'ye koşar,
// sonra her AI çıktısının insan tarafından eleştirileceği lokal bir review sayfası üretir.
//
// Kullanım:
//   node run.mjs --videos ~/TennisVideos/instagram [--limit 20] [--budget 1.0]
//     [--model gemini-2.5-pro] [--stroke forehand] [--handedness right|left|none]
//     [--out <dir>] [--mock]
//
// Anahtar: tools/swing-bench/.env içinde GEMINI_VIDEO_API_KEY=... (veya GEMINI_API_KEY).
// .env repoya girmez (.gitignore). Anahtar hiçbir çıktıya/loga yazılmaz.
//
// Çıktı: <videos>/_bench/run-<zaman>/ altında results.json + review.html + clips/ linkleri.
// Bütçe: --budget (USD, varsayılan 1.0) tahmini maliyeti aşacak ilk klipte durur.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  buildSystemParts,
  GENERATION_CONFIG,
  parseScoredAnalysis,
  userPrompt,
} from "../../supabase/functions/swing-analysis/prompts.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));

// ---------- args ----------
const args = process.argv.slice(2);
function flag(name, dflt) {
  const i = args.indexOf(`--${name}`);
  if (i === -1) return dflt;
  const v = args[i + 1];
  return v === undefined || v.startsWith("--") ? true : v;
}
const VIDEOS_DIR = expandHome(String(flag("videos", path.join(os.homedir(), "TennisVideos", "instagram"))));
const LIMIT = Number(flag("limit", 20));
const BUDGET = Number(flag("budget", 1.0));
const MOCK = flag("mock", false) === true;
const STROKE_OVERRIDE = flag("stroke", null);
const HANDED = String(flag("handedness", "right")); // uygulama şu an right gönderiyor — prod ile aynı
const OUT_OVERRIDE = flag("out", null);

function expandHome(p) {
  return p.startsWith("~") ? path.join(os.homedir(), p.slice(1)) : p;
}

// ---------- .env ----------
function loadDotEnv(file) {
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+?)\s*$/);
    if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}
loadDotEnv(path.join(HERE, ".env"));
const API_KEY = process.env.GEMINI_VIDEO_API_KEY || process.env.GEMINI_API_KEY || "";
const MODEL = String(flag("model", process.env.SWING_GEMINI_MODEL || "gemini-2.5-pro")); // prod şu an pro

const redact = (s) => (API_KEY ? String(s).replaceAll(API_KEY, "[KEY]") : String(s));

// ---------- fiyatlar (USD / 1M token) ----------
const PRICES = {
  "gemini-2.5-pro": { in: 1.25, out: 10.0, outEst: 1500 },   // outEst: thinking dahil kaba tahmin
  "gemini-2.5-flash": { in: 0.30, out: 2.50, outEst: 900 },
  "gemini-2.5-flash-lite": { in: 0.10, out: 0.40, outEst: 900 },
};
const priceOf = (m) => PRICES[m] ?? PRICES["gemini-2.5-pro"];

// video token'ları: ~258/kare (varsayılan çözünürlük) × 5 fps + ses ~32/sn + prompt ~1400
function estimateCostUSD(durS, model) {
  const p = priceOf(model);
  const inTok = durS * 5 * 258 + durS * 32 + 1400;
  return (inTok * p.in + p.outEst * p.out) / 1e6 * 1.25; // %25 pay
}

// ---------- video keşfi ----------
const EXT = new Set([".mp4", ".mov", ".m4v"]);
const MIME = { ".mp4": "video/mp4", ".mov": "video/quicktime", ".m4v": "video/x-m4v" };
const STROKE_HINTS = [
  [/session|match|mac|rally|ralli/i, "session"],
  [/fore|fh/i, "forehand"],
  [/back|bh/i, "backhand"],
  [/serv/i, "serve"],
  [/volley|vole/i, "volley"],
  [/foot|ayak/i, "footwork"],
];
function inferStroke(relPath) {
  if (STROKE_OVERRIDE) return String(STROKE_OVERRIDE);
  for (const [re, s] of STROKE_HINTS) if (re.test(relPath)) return s;
  return null;
}
function ffprobeDuration(file) {
  const r = spawnSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file], { encoding: "utf8" });
  const d = parseFloat((r.stdout || "").trim());
  return Number.isFinite(d) ? d : null;
}
function scanVideos(root) {
  const found = [];
  const walk = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.name.startsWith(".") || e.name === "_bench") continue;
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (EXT.has(path.extname(e.name).toLowerCase())) found.push(p);
    }
  };
  walk(root);
  return found.sort();
}

// ---------- Gemini ----------
async function uploadToFilesAPI(file, mime) {
  const bytes = fs.readFileSync(file);
  const start = await fetch(`https://generativelanguage.googleapis.com/upload/v1beta/files?key=${API_KEY}`, {
    method: "POST",
    headers: {
      "X-Goog-Upload-Protocol": "resumable",
      "X-Goog-Upload-Command": "start",
      "X-Goog-Upload-Header-Content-Length": String(bytes.length),
      "X-Goog-Upload-Header-Content-Type": mime,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ file: { display_name: path.basename(file) } }),
  });
  if (!start.ok) throw new Error(`upload start ${start.status}: ${redact(await start.text())}`);
  const uploadUrl = start.headers.get("x-goog-upload-url");
  if (!uploadUrl) throw new Error("upload URL yok");
  const up = await fetch(uploadUrl, {
    method: "POST",
    headers: { "X-Goog-Upload-Command": "upload, finalize", "X-Goog-Upload-Offset": "0" },
    body: bytes,
  });
  if (!up.ok) throw new Error(`upload ${up.status}: ${redact(await up.text())}`);
  let info = (await up.json()).file;
  for (let i = 0; i < 60 && info.state === "PROCESSING"; i++) {
    await new Promise((r) => setTimeout(r, 3000));
    const g = await fetch(`https://generativelanguage.googleapis.com/v1beta/${info.name}?key=${API_KEY}`);
    info = await g.json();
  }
  if (info.state !== "ACTIVE") throw new Error(`dosya durumu: ${info.state}`);
  return info.uri;
}

async function analyzeClip(file, mime, stroke, handedness) {
  const sizeMB = fs.statSync(file).size / 1e6;
  let videoPart;
  if (sizeMB > 15) {
    process.stdout.write(`   yükleniyor (Files API, ${sizeMB.toFixed(0)}MB)… `);
    const uri = await uploadToFilesAPI(file, mime);
    videoPart = { file_data: { mime_type: mime, file_uri: uri }, video_metadata: { fps: 5 } };
  } else {
    videoPart = { inline_data: { mime_type: mime, data: fs.readFileSync(file).toString("base64") }, video_metadata: { fps: 5 } };
  }
  // Prod geminiBody'nin birebir aynısı (index.ts ile aynı modülden):
  const body = {
    systemInstruction: { parts: buildSystemParts(stroke, handedness, "") },
    contents: [{ role: "user", parts: [videoPart, { text: userPrompt(stroke) }] }],
    generationConfig: GENERATION_CONFIG,
  };
  for (let attempt = 1; ; attempt++) {
    const resp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}`,
      { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body), signal: AbortSignal.timeout(240_000) },
    );
    if (resp.ok) {
      const data = await resp.json();
      const parts = data?.candidates?.[0]?.content?.parts;
      const text = Array.isArray(parts) ? parts.map((p) => p.text ?? "").join("\n").trim() : "";
      if (!text) throw new Error(`boş yanıt: ${redact(JSON.stringify(data).slice(0, 300))}`);
      const usage = data?.usageMetadata ?? null;
      return { ...parseScoredAnalysis(text), usage };
    }
    const detail = redact((await resp.text()).slice(0, 300));
    if (attempt === 1 && (resp.status === 429 || resp.status >= 500)) {
      process.stdout.write(`   ${resp.status} → 20 sn bekleyip tekrar… `);
      await new Promise((r) => setTimeout(r, 20_000));
      continue;
    }
    throw new Error(`gemini ${resp.status}: ${detail}`);
  }
}

function mockAnalysis(stroke, i) {
  const texts = [
    `I can see 3 ${stroke}s in this clip.\n\n**What's working**\nYou turn your shoulders early and your base stays wide through contact. [MOCK]\n\n**Top fixes**\nYour finish stalls at shoulder height → Cue: "brush up, finish over the shoulder" → Drill: 10 shadow swings ending with the racquet over your left shoulder. [MOCK]\n\n**One thing to try next**\nFilm 5 reps from the same rear angle and focus only on the high finish. [MOCK]`,
    `I can see 1 ${stroke} — and the count in this sentence is deliberately wrong for testing. [MOCK]\n\n**What's working**\nGood spacing to the ball. [MOCK]\n\n**Top fixes**\nContact drifts late → Cue: "meet it out front" → Drill: drop-feed 10 balls, freeze the finish. [MOCK]\n\n**One thing to try next**\nOne-bounce rhythm drill. [MOCK]`,
  ];
  return { analysis: texts[i % texts.length], score: 55 + (i * 7) % 30, usage: null };
}

// ---------- review.html ----------
function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

function buildReviewHtml(run, results) {
  const data = JSON.stringify({ run, results }).replace(/<\//g, "<\\/");
  return `<!DOCTYPE html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Swing Bench — ${esc(run.id)}</title>
<style>
  :root { --clay:#C65C31; --claybright:#E4894F; --cream:#E9DECB; --parchment:#FCF7EE; --sand:#E1D1B8; --ink:#1E2938; --inksoft:#4A4640; --gold:#D99E19; --moss:#6C8366; }
  * { box-sizing:border-box; }
  body { margin:0; font:15px/1.55 -apple-system,system-ui,sans-serif; background:var(--parchment); color:var(--ink); }
  header { position:sticky; top:0; z-index:5; background:var(--ink); color:var(--parchment); padding:10px 20px; display:flex; gap:18px; align-items:baseline; flex-wrap:wrap; }
  header h1 { font-size:16px; margin:0; } header .meta { opacity:.75; font-size:12.5px; }
  #stats { display:flex; gap:14px; font-size:12.5px; flex-wrap:wrap; }
  #stats b { color:var(--gold); }
  main { max-width:1080px; margin:0 auto; padding:20px; }
  .card { background:#fff; border:1px solid var(--sand); border-radius:16px; margin-bottom:22px; overflow:hidden; display:grid; grid-template-columns: 400px 1fr; }
  @media (max-width:860px){ .card { grid-template-columns:1fr; } }
  .vid { background:var(--ink); display:flex; align-items:center; } .vid video { width:100%; max-height:460px; }
  .body { padding:16px 18px; min-width:0; }
  .fname { font-weight:700; font-size:13.5px; word-break:break-all; }
  .chips { margin:6px 0 10px; display:flex; gap:6px; flex-wrap:wrap; }
  .chip { font-size:11.5px; padding:2px 9px; border-radius:99px; background:var(--cream); color:var(--inksoft); }
  .chip.score { background:var(--gold); color:#fff; font-weight:700; }
  .chip.err { background:#B33; color:#fff; }
  .analysis { background:var(--parchment); border:1px solid var(--sand); border-radius:10px; padding:12px 14px; font-size:13.5px; max-height:300px; overflow:auto; }
  fieldset { border:1px solid var(--sand); border-radius:10px; margin:12px 0 0; padding:10px 12px; }
  legend { font-size:12px; font-weight:700; color:var(--clay); padding:0 6px; }
  .row { display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin:4px 0; font-size:13px; }
  .seg { display:inline-flex; border:1px solid var(--sand); border-radius:8px; overflow:hidden; }
  .seg button { border:0; background:#fff; padding:5px 12px; font-size:13px; cursor:pointer; color:var(--inksoft); }
  .seg button.on { background:var(--clay); color:#fff; font-weight:600; }
  select,input[type=number],textarea { border:1px solid var(--sand); border-radius:8px; padding:5px 8px; font:inherit; font-size:13px; background:#fff; }
  textarea { width:100%; min-height:52px; resize:vertical; }
  .stars { display:inline-flex; gap:2px; } .stars button { border:0; background:none; font-size:20px; cursor:pointer; color:var(--sand); padding:0 1px; }
  .stars button.on { color:var(--gold); }
  .savehint { font-size:11.5px; color:var(--moss); margin-left:auto; }
  .actions { position:sticky; bottom:0; background:var(--parchment); border-top:1px solid var(--sand); padding:12px 20px; display:flex; gap:10px; justify-content:center; }
  .actions button { border:0; border-radius:10px; padding:10px 18px; font:inherit; font-weight:700; cursor:pointer; }
  #export { background:var(--clay); color:#fff; } #copy { background:var(--ink); color:#fff; }
  .note { text-align:center; color:var(--inksoft); font-size:12.5px; margin:8px 0 30px; }
</style></head><body>
<header><h1>🎾 Swing Bench</h1><span class="meta" id="runmeta"></span><span id="stats"></span></header>
<main id="cards"></main>
<div class="note">Değerlendirmeler tarayıcıda otomatik kaydedilir (localStorage). Bitince <b>verdicts.json indir</b> ile dışa aktar, dosyayı Claude'a ver.</div>
<div class="actions"><button id="export">⬇︎ verdicts.json indir</button><button id="copy">⧉ Özeti panoya kopyala</button></div>
<script>
const DATA = ${data};
const KEY = "swingbench-" + DATA.run.id;
const store = JSON.parse(localStorage.getItem(KEY) || "{}");
const save = () => localStorage.setItem(KEY, JSON.stringify(store));
const V = (f) => (store[f] ??= { strokeOk:null, actualStroke:"", countOk:null, actualCount:"", fabrication:false, quality:0, notes:"" });

function md(s){ return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")
  .replace(/\\*\\*(.+?)\\*\\*/g,"<strong>$1</strong>").replace(/\\n/g,"<br>"); }

const STROKES = ["forehand","backhand","serve","volley","footwork","karışık","belirsiz"];
const cards = document.getElementById("cards");
for (const r of DATA.results) {
  const v = V(r.file);
  const el = document.createElement("section"); el.className = "card";
  el.innerHTML = \`
    <div class="vid"><video controls preload="metadata" src="clips/\${encodeURIComponent(r.clip)}"></video></div>
    <div class="body">
      <div class="fname">\${r.file}</div>
      <div class="chips">
        <span class="chip">istenen: \${r.stroke}</span>
        <span class="chip">\${r.durationS ? r.durationS.toFixed(0)+" sn" : "?"}</span>
        <span class="chip">\${DATA.run.model}</span>
        \${r.score != null ? '<span class="chip score">SCORE '+r.score+'</span>' : ""}
        \${r.error ? '<span class="chip err">HATA</span>' : ""}
      </div>
      \${r.error ? '<div class="analysis">'+md(r.error)+'</div>'
                 : '<div class="analysis">'+md(r.analysis||"")+'</div>'}
      <fieldset><legend>Senin kararın</legend>
        <div class="row">Vuruş tipi doğru mu?
          <span class="seg" data-k="strokeOk"><button data-v="y">Doğru</button><button data-v="n">Yanlış</button></span>
          <select data-k="actualStroke" style="display:\${v.strokeOk==='n'?'inline-block':'none'}">
            <option value="">gerçekte…</option>\${STROKES.map(s=>'<option>'+s+'</option>').join("")}</select>
        </div>
        <div class="row">Sayım doğru mu?
          <span class="seg" data-k="countOk"><button data-v="y">Doğru</button><button data-v="n">Yanlış</button><button data-v="none">Söylemedi</button></span>
          <label>gerçek sayı <input type="number" min="0" max="99" data-k="actualCount" value="\${v.actualCount}" style="width:60px"></label>
        </div>
        <div class="row"><label><input type="checkbox" data-k="fabrication" \${v.fabrication?"checked":""}> Uydurma var (görmediği şeyi anlatıyor)</label></div>
        <div class="row">Yorum kalitesi <span class="stars" data-k="quality">\${[1,2,3,4,5].map(n=>'<button data-v="'+n+'">★</button>').join("")}</span><span class="savehint">✓ otomatik kayıt</span></div>
        <textarea data-k="notes" placeholder="Not — neresi isabetli, neresi saçma?">\${v.notes}</textarea>
      </fieldset>
    </div>\`;
  cards.appendChild(el);

  const sync = () => {
    el.querySelectorAll(".seg").forEach(seg => {
      const k = seg.dataset.k;
      seg.querySelectorAll("button").forEach(b => b.classList.toggle("on", String(v[k]) === b.dataset.v));
    });
    const sel = el.querySelector("select[data-k=actualStroke]");
    if (sel) sel.style.display = v.strokeOk === "n" ? "inline-block" : "none";
    el.querySelectorAll(".stars button").forEach(b => b.classList.toggle("on", Number(b.dataset.v) <= v.quality));
    stats();
  };
  el.querySelectorAll(".seg button").forEach(b => b.onclick = () => { v[b.closest(".seg").dataset.k] = b.dataset.v; save(); sync(); });
  el.querySelectorAll(".stars button").forEach(b => b.onclick = () => { v.quality = Number(b.dataset.v); save(); sync(); });
  el.querySelector("select[data-k=actualStroke]").onchange = (e) => { v.actualStroke = e.target.value; save(); };
  el.querySelector("input[data-k=actualCount]").oninput = (e) => { v.actualCount = e.target.value; save(); };
  el.querySelector("input[data-k=fabrication]").onchange = (e) => { v.fabrication = e.target.checked; save(); stats(); };
  el.querySelector("textarea[data-k=notes]").oninput = (e) => { v.notes = e.target.value; save(); };
  sync();
}

function stats(){
  const fs = DATA.results.map(r=>r.file);
  const vs = fs.map(f=>store[f]).filter(v=>v && (v.strokeOk||v.countOk||v.quality||v.fabrication));
  const n = vs.length, tot = fs.length;
  const pct = (a,b)=> b? Math.round(100*a/b)+"%" : "–";
  const sOk = vs.filter(v=>v.strokeOk==="y").length, sAll = vs.filter(v=>v.strokeOk).length;
  const cOk = vs.filter(v=>v.countOk==="y").length, cAll = vs.filter(v=>v.countOk==="y"||v.countOk==="n").length;
  const fab = vs.filter(v=>v.fabrication).length;
  const qs = vs.filter(v=>v.quality); const q = qs.length? (qs.reduce((a,v)=>a+v.quality,0)/qs.length).toFixed(1) : "–";
  document.getElementById("stats").innerHTML =
    \`değerlendirilen <b>\${n}/\${tot}</b> · vuruş tipi <b>\${pct(sOk,sAll)}</b> · sayım <b>\${pct(cOk,cAll)}</b> · uydurma <b>\${pct(fab,n)}</b> · kalite <b>\${q}</b>\`;
}
document.getElementById("runmeta").textContent = \`\${DATA.run.id} · \${DATA.run.model} · \${DATA.results.length} klip\`;
stats();

function verdictsPayload(){ return { run: DATA.run.id, model: DATA.run.model, verdicts: Object.fromEntries(DATA.results.map(r=>[r.file, store[r.file]||null])) }; }
document.getElementById("export").onclick = () => {
  const blob = new Blob([JSON.stringify(verdictsPayload(), null, 2)], { type:"application/json" });
  const a = Object.assign(document.createElement("a"), { href:URL.createObjectURL(blob), download:"verdicts-"+DATA.run.id+".json" });
  a.click();
};
document.getElementById("copy").onclick = async (e) => {
  await navigator.clipboard.writeText(JSON.stringify(verdictsPayload()));
  e.target.textContent = "✓ kopyalandı"; setTimeout(()=>e.target.textContent="⧉ Özeti panoya kopyala", 1500);
};
</script></body></html>`;
}

// ---------- main ----------
async function main() {
  if (!fs.existsSync(VIDEOS_DIR)) {
    console.error(`✗ Video klasörü yok: ${VIDEOS_DIR}\n  Oluştur + klipleri koy, ya da --videos <dir> ver.`);
    process.exit(1);
  }
  if (!MOCK && !API_KEY) {
    console.error("✗ Anahtar yok. tools/swing-bench/.env dosyasına şunu yaz:\n  GEMINI_VIDEO_API_KEY=<anahtar>\n  (UI önizlemesi için anahtarsız: --mock)");
    process.exit(1);
  }

  const all = scanVideos(VIDEOS_DIR);
  if (all.length === 0) {
    console.error(`✗ ${VIDEOS_DIR} içinde video yok (.mp4/.mov/.m4v).`);
    process.exit(1);
  }

  const runId = new Date().toISOString().slice(0, 16).replace(/[-T:]/g, "").replace(/^(\d{8})(\d{4})$/, "$1-$2");
  const outDir = OUT_OVERRIDE ? expandHome(String(OUT_OVERRIDE)) : path.join(VIDEOS_DIR, "_bench", `run-${runId}`);
  const clipsDir = path.join(outDir, "clips");
  fs.mkdirSync(clipsDir, { recursive: true });

  const run = { id: runId, model: MOCK ? `${MODEL} [MOCK]` : MODEL, videosDir: VIDEOS_DIR, startedAt: new Date().toISOString(), handedness: HANDED === "none" ? null : HANDED };
  const results = [];
  const skipped = [];
  let spent = 0, taken = 0;

  console.log(`swing-bench → ${all.length} video bulundu · model=${run.model} · limit=${LIMIT} · bütçe=$${BUDGET.toFixed(2)}\nÇıktı: ${outDir}\n`);

  for (const file of all) {
    if (taken >= LIMIT) { skipped.push([file, "limit"]); continue; }
    const rel = path.relative(VIDEOS_DIR, file);
    const stroke = inferStroke(rel);
    if (!stroke) { skipped.push([rel, "vuruş tipi çıkarılamadı (dosya adına forehand/backhand/serve/volley yaz veya --stroke ver)"]); continue; }
    const durationS = ffprobeDuration(file);
    if (durationS !== null && durationS > 120) { skipped.push([rel, `${Math.round(durationS)} sn — uzun video bench'e girmez → stroke-miner (Faz 3)`]); continue; }
    const est = estimateCostUSD(durationS ?? 30, MODEL);
    if (!MOCK && spent + est > BUDGET) { skipped.push([rel, `bütçe (tahmini +$${est.toFixed(3)} > kalan $${(BUDGET - spent).toFixed(3)})`]); continue; }

    taken++;
    const clipName = `${String(taken).padStart(2, "0")}-${path.basename(file).replace(/[^\w.\-]+/g, "_")}`;
    try { fs.symlinkSync(file, path.join(clipsDir, clipName)); } catch { fs.copyFileSync(file, path.join(clipsDir, clipName)); }

    process.stdout.write(`[${taken}/${Math.min(LIMIT, all.length)}] ${rel} (${stroke}${durationS ? `, ${durationS.toFixed(0)} sn` : ""}, ~$${est.toFixed(3)}) … `);
    const entry = { file: rel, clip: clipName, stroke, durationS, estCost: est, analysis: null, score: null, error: null };
    try {
      const mime = MIME[path.extname(file).toLowerCase()] ?? "video/mp4";
      const out = MOCK ? mockAnalysis(stroke, taken) : await analyzeClip(file, mime, stroke, run.handedness);
      entry.analysis = out.analysis; entry.score = out.score;
      if (out.usage) entry.usage = out.usage;
      spent += MOCK ? 0 : est;
      console.log(`✓ SCORE ${out.score ?? "?"}`);
    } catch (e) {
      entry.error = redact(e?.message ?? String(e));
      console.log(`✗ ${entry.error}`);
    }
    results.push(entry);
    fs.writeFileSync(path.join(outDir, "results.json"), JSON.stringify({ run, results, skipped }, null, 2)); // her adımda — kesinti güvenli
  }

  fs.writeFileSync(path.join(outDir, "review.html"), buildReviewHtml(run, results));
  console.log(`\nBitti: ${results.length} analiz · tahmini harcama ~$${spent.toFixed(2)} · atlanan ${skipped.length}`);
  for (const [f, why] of skipped.slice(0, 12)) console.log(`  atlandı: ${f} — ${why}`);
  console.log(`\nİncele:\n  open "${path.join(outDir, "review.html")}"\n  (video oynamazsa: cd "${outDir}" && python3 -m http.server 8734 → http://localhost:8734/review.html)`);
}

main().catch((e) => { console.error("✗", redact(e?.stack ?? String(e))); process.exit(1); });
