#!/usr/bin/env python3
"""labelcheck — eğitim kliplerini tek-tuşla doğrulama/yeniden-etiketleme sayfası üretir.

Çıktı: <trainingDir>/labelcheck.html — klipler sınıf klasörlerinden GÖRECELİ oynar
(dosyayı çift tıklayıp açmak yeter). Kararlar localStorage'a yazılır; "indir" ile
relabels.json çıkar; apply_labels.py bunu uygulayıp dosyaları taşır.

Kullanım: python3 labelcheck.py ~/TennisVideos/_training/v0
"""
import json, sys
from pathlib import Path

LABELS = ["forehand", "backhand", "smash", "tweener", "cop"]  # cop = çöp/kes
NICE = {"forehand": "FH", "backhand": "BH", "smash": "Smaç", "tweener": "Bacak arası", "cop": "Çöp"}

root = Path(sys.argv[1]).expanduser()
clips = []
for cls in ("forehand", "backhand", "smash"):
    for p in sorted((root / cls).glob("*.mp4")):
        clips.append({"rel": f"{cls}/{p.name}", "label": cls, "name": p.stem})

data = json.dumps(clips).replace("</", "<\\/")
html = """<!DOCTYPE html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Etiket Kontrol — stroke-miner</title>
<style>
:root { --clay:#C65C31; --parchment:#FCF7EE; --sand:#E1D1B8; --ink:#1E2938; --gold:#D99E19; --moss:#6C8366; }
* { box-sizing:border-box; } body { margin:0; font:14px/1.5 -apple-system,system-ui,sans-serif; background:var(--parchment); color:var(--ink); }
header { position:sticky; top:0; z-index:5; background:var(--ink); color:var(--parchment); padding:10px 16px; display:flex; gap:16px; align-items:center; flex-wrap:wrap; }
header b { color:var(--gold); }
main { display:grid; grid-template-columns:repeat(auto-fill,minmax(250px,1fr)); gap:12px; padding:14px; max-width:1400px; margin:0 auto; }
.card { background:#fff; border:1px solid var(--sand); border-radius:12px; overflow:hidden; }
.card.changed { outline:3px solid var(--gold); }
.card video { width:100%; aspect-ratio:9/16; background:#000; display:block; max-height:330px; object-fit:cover; }
.meta { padding:6px 8px 8px; }
.name { font-size:11px; color:#777; word-break:break-all; }
.btns { display:flex; flex-wrap:wrap; gap:4px; margin-top:6px; }
.btns button { border:1px solid var(--sand); background:#fff; border-radius:7px; padding:4px 8px; font-size:12px; cursor:pointer; }
.btns button.cur { background:var(--moss); color:#fff; border-color:var(--moss); font-weight:700; }
.btns button.sel { background:var(--clay); color:#fff; border-color:var(--clay); font-weight:700; }
.actions { position:sticky; bottom:0; background:var(--parchment); border-top:1px solid var(--sand); padding:10px; display:flex; gap:10px; justify-content:center; }
.actions button { border:0; border-radius:10px; padding:10px 16px; font:inherit; font-weight:700; cursor:pointer; background:var(--clay); color:#fff; }
.note { text-align:center; font-size:12px; color:#666; padding:0 12px 8px; }
</style></head><body>
<header>🏷️ <b>Etiket Kontrol</b><span id="prog"></span><span style="opacity:.7;font-size:12px">Videoya dokun → oynar (döngülü). Etiket doğruysa hiçbir şey yapma; yanlışsa doğru düğmeye bas.</span></header>
<main id="grid"></main>
<div class="note">Kararlar otomatik kaydedilir. Bitince <b>relabels.json indir</b> → Claude'a ver (yalnız DEĞİŞENLER dışa aktarılır).</div>
<div class="actions"><button id="export">⬇︎ relabels.json indir</button><button id="copy">⧉ Panoya kopyala</button></div>
<script>
const CLIPS = __DATA__;
const LABELS = __LABELS__;
const NICE = __NICE__;
const KEY = "labelcheck-v0";
const store = JSON.parse(localStorage.getItem(KEY) || "{}");
const save = () => { localStorage.setItem(KEY, JSON.stringify(store)); prog(); };

const grid = document.getElementById("grid");
for (const c of CLIPS) {
  const el = document.createElement("div"); el.className = "card"; el.id = "c-" + c.rel;
  el.innerHTML = `
    <video preload="metadata" muted playsinline loop src="${encodeURI(c.rel)}"></video>
    <div class="meta"><div class="name">${c.name} · şu an: <b>${NICE[c.label]}</b></div>
    <div class="btns">${LABELS.map(l => `<button data-l="${l}">${NICE[l]}</button>`).join("")}</div></div>`;
  const vid = el.querySelector("video");
  // poster yerine: metadata gelince temas anına sar (en bilgilendirici kare görünsün)
  vid.addEventListener("loadedmetadata", () => { try { vid.currentTime = 1.3; } catch (_) {} }, { once: true });
  vid.onclick = () => { if (vid.paused) { vid.currentTime = 0; vid.play(); } else vid.pause(); };
  const sync = () => {
    const sel = store[c.rel];
    el.classList.toggle("changed", !!sel && sel !== c.label);
    el.querySelectorAll(".btns button").forEach(b => {
      b.classList.toggle("cur", b.dataset.l === c.label && (!sel || sel === c.label));
      b.classList.toggle("sel", !!sel && sel !== c.label && b.dataset.l === sel);
    });
  };
  el.querySelectorAll(".btns button").forEach(b => b.onclick = () => {
    if (b.dataset.l === c.label) delete store[c.rel]; else store[c.rel] = b.dataset.l;
    save(); sync();
  });
  sync(); grid.appendChild(el);
}
function prog() {
  const n = Object.keys(store).length;
  document.getElementById("prog").textContent = `${CLIPS.length} klip · ${n} değişiklik`;
}
prog();
const payload = () => ({ relabels: store });
document.getElementById("export").onclick = () => {
  const a = Object.assign(document.createElement("a"),
    { href: URL.createObjectURL(new Blob([JSON.stringify(payload(), null, 1)], {type:"application/json"})), download: "relabels.json" });
  a.click();
};
document.getElementById("copy").onclick = async (e) => {
  await navigator.clipboard.writeText(JSON.stringify(payload()));
  e.target.textContent = "✓ kopyalandı"; setTimeout(() => e.target.textContent = "⧉ Panoya kopyala", 1500);
};
</script></body></html>
"""
html = html.replace("__DATA__", data).replace("__LABELS__", json.dumps(LABELS)).replace("__NICE__", json.dumps(NICE, ensure_ascii=False))
out = root / "labelcheck.html"
out.write_text(html)
print(f"{out} — {len(clips)} klip")
