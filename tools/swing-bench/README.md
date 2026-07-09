# swing-bench — izle · yorumlat · eleştir

Arşiv kliplerini **prod'un birebir prompt'uyla** (edge fonksiyonun kendi `prompts.mjs`
modülünden import edilir — kopya değil) doğrudan Gemini'ye koşar, sonra her çıktının
insan tarafından not verildiği lokal bir `review.html` üretir. Eleştiriler baseline
ölçümü + ground-truth etiket + regresyon seti olur (plan: docs/SWING-PIPELINE-PLAN.md).

## Kurulum (bir kez)

```bash
cd tools/swing-bench
cp env.example .env   # sonra .env içine anahtarı yapıştır (repoya girmez)
```

`.env` içeriği: `GEMINI_VIDEO_API_KEY=<Google AI Studio'daki faturalı anahtar>`

## Kullanım

```bash
# UI'ı anahtarsız/parasız önizle:
node run.mjs --videos ~/TennisVideos/instagram --mock

# Gerçek koşu (varsayılan: en fazla 20 klip, $1 bütçe tavanı, prod modeli):
node run.mjs --videos ~/TennisVideos/instagram

# Seçenekler:
#   --limit 30            en fazla N klip
#   --budget 2.0          USD tavan — tahmini maliyet aşılınca durur
#   --model gemini-2.5-flash   (varsayılan: SWING_GEMINI_MODEL ?? gemini-2.5-pro = prod)
#   --stroke forehand     dosya adından çıkarım yerine hepsine tek tip
#   --handedness none     prod uygulama "right" gönderiyor; aynısı varsayılan
#   --out <dir>           çıktı klasörü (varsayılan: <videos>/_bench/run-<zaman>)
```

- Vuruş tipi **dosya adından/klasörden** çıkarılır: `forehand|fh`, `backhand|bh`,
  `serv`, `volley`, `foot`, `session|match|rally`. Çıkarılamazsa klip atlanır (ya adlandır
  ya `--stroke` ver).
- \>120 sn videolar bench'e girmez (onlar Faz 3 stroke-miner'ın işi) · >15MB klipler
  otomatik Files API ile yüklenir · 429/5xx'te bir kez 20 sn bekleyip yeniden dener ·
  `results.json` her klipten sonra yazılır (kesinti güvenli).

## Değerlendirme

`open .../review.html` → her klip için: vuruş tipi doğru/yanlış (+gerçeği), sayım
doğru/yanlış (+gerçek sayı), **uydurma var** bayrağı, kalite 1-5, not. Otomatik kaydolur
(localStorage); bitince **verdicts.json indir** ya da **panoya kopyala** → Claude'a ver.
Video oynamazsa (tarayıcı file:// kısıtı): `cd <run-dizini> && python3 -m http.server 8734`.

## Güvenlik / maliyet

- `.env` gitignore'da; anahtar loglara/çıktılara yazılmaz (hata metinleri redakte edilir).
- Bütçe tavanı varsayılan **$1** — Pro'da ~15-25 kısa klip demek. Kaba fiyat: ~10 sn'lik
  klip Pro'da ~$0.03, Flash'ta ~$0.008.
- Prod'a hiç dokunmaz: Supabase/edge/kullanım sayaçları bypass — doğrudan Gemini.
