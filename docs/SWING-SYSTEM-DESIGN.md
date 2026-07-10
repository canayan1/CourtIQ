# Swing Analysis — Sistem Tasarımı v2 ("Güven Mimarisi")
**10 Tem 2026 · Durum: ONAY BEKLİYOR · Sahibi: Can + Claude**

Neden bu doküman: bugüne kadar hata sınıflarını üretimde teker teker keşfettik
(uydurma servis ×2, papağan örnek ×2, şişik skor, yanlış sayım, kadraj-dışı).
Bu belge girdi uzayını BAŞTAN sayar, her vakanın kararını önceden verir, her
bilinen/öngörülen hata sınıfına muhafız + otomatik test bağlar. Bundan sonra
kural: **golden suite yeşil değilse deploy yok; yeni saha hatası = önce yeni
golden vaka, sonra düzeltme.** Can'ın rolü tek tek test etmek değil, golden
setini onaylamak.

---

## 1. Değişmezler (INV — sistemin anayasası)

- **INV-1 · Ölçmediğini söyleme.** Rapordaki her iddia ya bir cihaz ölçümüne
  (sayı, başüstü oranı, vuruş etiketi, poz metriği) dayanır ya da açıkça
  "görsel koçluk gözlemi"dir. İkisi UI'da ayrı render edilir (§7).
- **INV-2 · LLM asla saymaz.** Sayı DSP+Vision'dan gelir ya da yoktur.
- **INV-3 · LLM vuruş kimliğini tek başına onaylayamaz.** Kimlik cihazda
  belirlenir (bugün: başüstü-çoğunluk; hedef: sınıflandırıcı). LLM yazardır,
  hakim değil.
- **INV-4 · Skor üretilmez, hesaplanır.** Hedef durumda skor = rubrik(metrikler);
  geçiş döneminde LLM önerisi sunucuda rubrik bandına KIRPILIR (§6.3).
- **INV-5 · Belirsizlikte dürüst bozulma.** Sıra: tam rapor → skorsuz rapor →
  sayısız rapor → gerekçeli red + eyleme dönük yönlendirme. Asla emin-görünümlü tahmin.
- **INV-6 · Prompt'ta örnek cümle YASAK.** Vuruş adı/sayı içeren her şablon
  papağanlanır (iki kez yaşandı). Golden suite bunu lint'ler (T-3).
- **INV-7 · Golden suite yeşil değilse deploy yok.** İstisnasız.
- **INV-8 · Maliyet sınırlı.** Analiz başına üst sınır tasarımda (kare-yolu ≤16
  kare ≈ 20× ucuz); mevcut breaker'lar korunur.

## 2. Girdi uzayı ve KARAR TABLOSU (cihazda, yüklemeden önce)

Boyutlar: süre · ses izi · impact sayısı · insan-görünürlük oranı · başüstü
oranı · beyan edilen vuruş · (R3+) sınıflandırıcı oyları · kadraj kalitesi.

| # | Vaka | Tespit | Karar (cihazda) |
|---|---|---|---|
| D1 | Süre < 3 sn | ffprobe/AVAsset | RED: "Tek vuruş ~2 sn — 10-30 sn çek" |
| D2 | Süre > 90 sn |〃 | RED + kırpma önerisi ("ilk 30 sn'yi dene") |
| D3 | Ses izi yok / dümdüz | envelope | DEVAM, sayı YOK (edge sayıyı yasaklar) + UI "sayı ölçülemedi" rozeti |
| D4 | Ses var, impact=0 | detektör | DEVAM sayısız + UI notu ("vuruş sesi bulunamadı — rüzgâr/uzaklık?") |
| D5 | İnsan görünür < %70 impact | person gate | RED: kadraj rehberi ("vuruşların bir kısmında kadraj dışındasın") |
| D6 | serve beyan + başüstü < %50 | overhead | RED (canlı — 384eace) |
| D7 | FH/BH beyan + başüstü > %50 | overhead | RED (canlı) |
| D8 | (R3) sınıflandırıcı çoğunluğu ≠ beyan | classifier | RED değil TEKLİF: "Bu videoda çoğunlukla Backhand görüyorum (%92) — Backhand olarak analiz edeyim mi?" TEK DOKUNUŞLA geçiş |
| D9 | (R3) çoğunluk yok (karışık seans) | classifier | TEKLİF: vuruş başına bölümlü seans raporu (R4'te) ya da tek vuruş seçtir |
| D10 | Hepsi geçti | — | YÜKLE: kareler + ölçümler (§5) |

D8 kritik ürün kararı: yanlış beyan çıkmaz sokak değil, tek dokunuşluk düzeltme
anı — reddi lütfa çevirir.

## 3. Boru hattı (uçtan uca, aşama aşama)

```
[0 Çekim rehberi] → [1 Al+normalize] → [2 Ses impactları] → [3 Poz örnekleme]
→ [4 Vuruş kimliği] → [KARAR TABLOSU] → [5 Payload v2] → [6 LLM dil katmanı]
→ [7 UI durumları] → [8 Gözlemlenebilirlik] ; hepsini [9 Golden Suite] sarar
```

**0 · Çekim rehberi (önleyici):** kanonik açı ARKADAN kartı (canlı). R2+:
app-içi kamerada canlı kadraj kılavuzu ("şurada dur" dikdörtgeni + kırmızı/yeşil).

**1 · Al + normalize:** süre & ses-izi probu (D1-D3), 720p transcode (mevcut).

**2 · Ses impactları (CANLI):** HP-fark → 10 ms RMS → medyan+6·MAD → 1.4 sn
en-güçlü-tepe. GT kalibrasyonlu (duvar). AÇIK İŞ: kort akustiği doğrulaması
(kort videosunda 4/4 saydı ✓ ama tek örnek — golden'a kort vakaları eklenecek).
Gürültü emniyeti: impact yoğunluğu fiziksel üst sınırı aşarsa (sürekli <1.2 sn
aralık) "gürültülü ses" → D4 yoluna düş.

**3 · Poz örnekleme (KISMEN CANLI → R2'de tam):** bugün: insan-var + başüstü.
R2: her impact'te t−0.3/t/t+0.3 için 3D poz (VNDetectHumanBodyPose3DRequest) →
metrikler: omuz-hattı dönüş delta'sı (unit turn proxy'si), taban genişliği
(ayak bileği açıklığı/omuz genişliği), bitiş yüksekliği (bilek−omuz, t+0.3),
diz fleksiyonu (t−0.1, 3D açı), temas yüksekliği sınıfı (alçak/bel/omuz/başüstü),
kadraj kayması (kalça-x yörüngesi → D5 girdisi). ARKA-AÇI seti: derinlik
gerektiren metrik YOK (temas-önde verilmez — plan kararı).

**4 · Vuruş kimliği (R3):** DropVolleyStroke sınıflandırıcısı impact başına
60-kare pencerede → etiket+güven. Oy: güven ≥0.6 olanlar oylar; çoğunluk =
oyların ≥%60'ı. Eşik altı/model yoksa → bugünkü başüstü kuralları (D6/D7)
yedek. SERVİS İSTİSNASI: modelde serve sınıfı YOK (veri yok) → serve beyanı
R4'e kadar başüstü-çoğunluk kuralıyla doğrulanır; smash oyları başüstü-ailesi
sayılır. (Veri yol haritası §10.)

**5 · Payload sözleşmesi v2 (VERSİYONLU):**
```jsonc
{ "v": 2, "stroke": "forehand",
  "measured": { "count": 12, "overheadRatio": 0.08,
                "strokeVotes": {"backhand": 9, "forehand": 2},   // R3+
                "metrics": [ {"t": 3.4, "finishHigh": true, ...} ], // R2+
                "framing": 0.94 },
  "media": { "frames": [ {"t": 3.1, "jpeg": "<b64>"} ] },  // ≤16 kare, 768px q0.7
  "context": "..." }
```
Kareler impact-merkezli (impact başına t−0.4/−0.15/0/+0.15/+0.35; toplam ≤16).
Video gövdesi yalnızca kare çıkarımı BAŞARISIZSA yedek. Edge şemayı doğrular;
bilinmeyen `v` reddedilir (F14). Kazanç: ~20× ucuz girdi + temas anı kesin
görünür (5fps örnekleme kör noktası biter).

**6 · LLM dil katmanı (edge):**
- 6.1 Prompt = `ÖLÇÜLMÜŞ GERÇEKLER` bloğu (sayı, oranlar, oylar, metrikler) +
  koçluk referansı + güvenlik + format. Açık rol tanımı: *"You are the WRITER,
  not the judge. The facts below were measured by instruments; never contradict
  or re-derive them."*
- 6.2 VERIFIED sözleşmesi kalır (kemer-pantolon askısı; R3'te sınıflandırıcı
  yukarıda kestiği için nadiren tetiklenir). `no` → sunucu skoru siler.
- 6.3 SKOR (geçiş dönemi): LLM önerir, SUNUCU KIRPAR: `clamp(öneri, band)`;
  band = rubrik taslağı(§6.4)'ten metrik sayısına göre. R2 sonrası: skor
  tamamen `rubrik(metrikler)` — LLM skoru yazamaz, yalnızca AÇIKLAR.
- 6.4 Rubrik taslağı (R2'de kalibre edilir): taban 50 · bitiş yüksekliği ±6 ·
  taban genişliği ±5 · unit-turn ±8 · temas yüksekliği uygunluğu ±6 · denge
  (kalça salınımı) ±5 · tekrar tutarlılığı (metrik varyansı) ±10 → 16-90 bandı.
  Kusur↔skor tutarlılık kuralı prompt'ta kalır (3+ ciddi kusur → 30-40'lar).
- 6.5 Cevap: `{ analysis, score, scoreBasis: "measured"|"model", mismatch,
  factsEcho: {count, overheadRatio, votes} }` — app ölçümleri PROSE'A GÜVENMEDEN
  chip olarak basar (INV-1'in UI yüzü).

**7 · UI durumları:** başarı (rapor + "Ölçülenler" chip'leri + skor rozeti
`hesaplandı/model`) · redler D1-D9 (her biri eyleme dönük copy + varsa tek-dokunuş
düzeltme) · bozulmuş modlar ("sayı ölçülemedi", "skorsuz analiz") görünür rozetli.

**8 · Gözlemlenebilirlik (gizlilik-güvenli, video YOK):** log: kapı kararları,
sayılar, oranlar, mismatch oranı, skor dağılımı. Haftalık bakış: kapı isabet
oranları; mismatch'in üretimde yeniden yükselişi = regresyon alarmı.

## 4. FMEA — hata modu → muhafız → test

| # | Hata modu (kaynak) | Muhafız | Golden test |
|---|---|---|---|
| F1 | LLM yanlış sayar (saha) | INV-2: sayı DSP'den | T-1 sayı=GT |
| F2 | Servis uydurma (saha ×2) | D6 + serve sert kapısı + VERIFIED | T-2 serve-trap: yasak sözlük |
| F3 | Papağan örnek (saha ×2) | INV-6 + prompt lint | T-3: prompt'ta "I can see" vb. şablon yok |
| F4 | Şişik skor (saha) | 6.3 kırpma + kusur↔skor | T-4: skor ∈ band, kusur sayısıyla tutarlı |
| F5 | Kadraj dışı oyuncu (eğitimde %31!) | D5 + rehber | T-5 kadraj vakası → RED |
| F6 | Karışık video tek beyan (saha) | D6/7 bugün, D8/9 R3 | T-6 mixed-trap → RED/teklif |
| F7 | Sessiz video | D3 sayısız yol | T-7: cevapta hiç sayı yok |
| F8 | Kadrajda 2 kişi | poz seçimi: en büyük gövde (R2 spec) | T-8 (R2) |
| F9 | Rüzgâr/müzik | yoğunluk emniyeti (§3.2) | T-9: sayı YOK, uydurma sayı yok |
| F10 | >90 sn ralli | D2 | T-10 → RED |
| F11 | Gemini model drift'i | golden haftalık cron | T-ALL haftalık |
| F12 | Maliyet sıçraması | kare yolu + breaker | T-11: payload ≤ eşik |
| F13 | Sınıflandırıcı yanılır (tek-denek) | güven eşiği + başüstü yedeği + veri yol haritası | T-12 held-out eval ≥ hedef |
| F14 | App↔edge şema kayması | `v` alanı + red | T-13 şema |
| F15 | Refusal copy TR/EN kayması | tek copy tablosu | T-14 snapshot |

**Kural: her yeni saha hatası önce F-satırı + T-vakası olur, sonra düzeltilir.**

## 5. Golden Regression Suite (Can'ın "tek tek test etmeyeceğim" cevabı)

`tools/swing-bench` üstüne **golden modu**: `goldens.json` = vaka listesi:
```jsonc
{ "clip": "instagram/forehand_wall_9929.mov", "declared": "forehand",
  "expect": { "deviceGate": "pass", "verified": "yes",
              "countInText": 19, "scoreMax": 60,
              "forbidden": ["toss", "pronation", "trophy", "racquet drop"] } }
```
Üç seviye:
- **L1 (Mac, $0, saniyeler):** ses sayacı referans implementasyonu (miner) GT
  sayılara karşı; kapı kuralları (çoğunluk-başüstü, süre) scan çıktısına karşı.
- **L2 (Gemini, ~$0.5/koşu):** prod prompt'la gerçek çağrı → otomatik assert:
  VERIFIED doğruluğu, yasak sözlük taraması (beyan≠serve iken servis
  terminolojisi = FAIL), sayı-metin eşleşmesi, skor bandı, format başlıkları.
  İNSAN GEREKMEZ.
- **L3 (cihaz E2E):** sürüm başına 1 kez manuel duman testi (Can, 5 dk).

Golden set v1 (mevcut varlıklarla): 5 video × (doğru beyan + tuzak beyan) ≈ 12
vaka; her saha hatası seti büyütür. **Deploy öncesi zorunlu:** `bench golden`
yeşil. Haftalık cron: aynı set (F11 drift'e karşı).

## 6. Yayın fazları ve kapıları (go/no-go)

| Faz | İçerik | Kapı |
|---|---|---|
| R0 ✅ | sayaç+kapılar+VERIFIED (bugün canlı) | saha onayı |
| R1 | kare-yolu + factsEcho chip'leri + **golden v1 çalışır** | golden yeşil + maliyet ölçümü |
| R2 | 3D poz metrikleri + rubrik kırpma + kadraj kalitesi + 2-kişi seçimi | golden + "skorlar tutarlı" onayın |
| R3 | sınıflandırıcı entegrasyonu (D8/D9 + tek-dokunuş geçiş) | held-out eval (yeni FH verisiyle) ≥%85 + mismatch UX |
| R4 | serve verisi + serve sınıfı + seans modu geri (bölümlü rapor) | serve eval + golden mixed vakaları |
| R5 | skor tamamen hesaplanır + "on-device AI" iddiası + copy/marketing | tüm suite + App Store güncellemesi |

## 7. Veri yol haritası (R3/R4'ü besler)

1. **FH duvar seansı 2-3 dk, kadraj ORTASINDA** (v0.3 — FH↔BH karışmasını çözer)
2. **Servis seansı** (serve sınıfı doğar — R4 kapısı)
3. **Farklı oyuncular** (kulüp/öğrenci; genel doğruluk iddiasının şartı)
4. **Kort-yanı akustik seti** (sayaç kort kalibrasyonu — golden'a girer)
5. Her yeni set → miner → labelcheck (10 dk) → retrain → eval raporu.

## 8. Açık kararlar (Can)

- K1: D8 "tek dokunuşla vuruş değiştir" onayı (önerim: evet — reddi lütfa çevirir)
- K2: Skor geçiş dönemi görünürlüğü: kırpılmış-LLM skoru rozetle mi, R2'ye kadar gizli mi? (önerim: rozetli göster — "model tahmini" etiketiyle)
- K3: Golden L2 koşu bütçesi (~$0.5/koşu, deploy başına + haftalık ≈ ayda ~$3-5) onayı
- K4: Bench anahtarı (.env) — golden L2 bunsuz çalışamaz (hâlâ eksik)
