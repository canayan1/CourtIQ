# Viral hook içerik üretimi — deep research sentezi (4 Tem 2026)

5 paralel arama ajanı (Haiku, ~190K token — ucuz mod), kaynak zorunlu.
**Güven notu:** kaynakların çoğu pratisyen/ajans blogu (OpusClip, creatorflow,
auditsocials vb.) — sayıları kesin bilim değil YÖN göstergesi olarak oku.
Şüpheli bulduklarım işaretli.

---

## 1) Hook formülleri (kanıt derecesiyle)

Sayısal zemin: izleyicinin ~%50'si ilk 3 saniyede gidiyor; karar penceresi
~1.7 sn; geniş dağıtım için ~%70 tamamlanma oranı gerekiyor (directional);
insan yüzü ~+%35 tutundurma; kısa video yüksek tamamlanma > uzun video
düşük tamamlanma. (OpusClip, TrueFuture, Sink-or-Swim — pratisyen.)

Sıralı formüller:
1. **Contrarian** — "Herkes X der, ama aslında Y." (en yüksek 3sn tutuş)
2. **Pattern interrupt** — beklenmedik görüntü/cümleyle açılış
3. **Merak boşluğu / soru** — "Bunu yanlış mı yapıyorsun?"
4. **"Bilmek suç gibi"** — yasak meyve çerçevesi
5. **Hata/kırılganlık** — "X yüzünden maç kaybettim"
6. **Yüz + bold metin overlay** — sessiz izleyici için metin şart
7. **Zaman/verim** — "X'i 20 saniyede öğren"
8. **Numaralı liste** — "3 hata…"

Carousel ilk slaytı = aynı kurallar: tek büyük iddia, merak boşluğu,
kaydırma vaadi. (Bizim "You don't lose because of your forehand." tam
contrarian kalıbı.)

## 2) En ucuz üretim hattı — kritik bulgu

**AI video üretimi (Veo/Kling/Runway) app tanıtımı için GEREKSİZ.**
En iyi dönüşen indie-app formatı zaten: **gerçek ekran kaydı + hook metni +
altyazı** (Indie Hackers vakaları; $30-60k/ay'a ölçeklenen faceless app
hesapları). Ekran kaydı ücretsiz VE "orijinal içerik" sinyali güçlü
(AI-slop cezasından muaf).

**$0 çekirdek hat (önerilen):**
- Görüntü: `xcrun simctl io <udid> recordVideo` — simülatörden temiz kayıt
  (bu repo'da zaten yapıyoruz; onboarding_tour.mp4 böyle üretildi)
- Hook/senaryo metni: Claude (bu oturum — ücretsiz katman)
- Kurgu+altyazı: CapCut free (sınırsız otomatik altyazı) veya DaVinci (tam
  ücretsiz)
- Carousel: mevcut `build_slides.py` hattı (headless Chrome, $0)
- Yayın/analitik: Meta Business Suite (ücretsiz) + Metricool free
- Ses gerekirse: ElevenLabs free 10dk/ay (ticari için $6/ay Starter)

**≤$30/ay güçlendirme:** ElevenLabs Starter $6 + CapCut Pro $9.99 (+
istersen Ideogram $7 metinli görsel). AI video üretimine para YOK.

Fiyat kaynakları: elevenlabs.io/pricing, gamsgo CapCut 2026, eesel Kling,
Buffer/Metricool sayfaları. (Ajanın "Sora Eyl 2026'da kapandı" iddiası
doğrulanamaz — YOK SAY.)

## 3) Haftalık akış (4-6 saat, çoğu bana delege edilebilir)

- **Pzt 30dk — hook madenciliği:** TikTok Creative Center + rakip
  viralleri; 3 hook kalıbı seç. → *Claude'a: "bu haftanın 10 hook'unu yaz"*
- **Çar 90dk — toplu üretim:** 4-5 ekran kaydı (tek özellik/klip, 15-45sn),
  CapCut'ta altyazı + hook overlay. → *kayıtları ben simülatörden alırım;
  senaryo/overlay metinleri benden*
- **Cum 20dk — planlama:** haftaya yay (sabah/öğle/akşam pik saatler),
  aynı özelliği 3 farklı hook'la test et.
- **Cum 20dk — iterasyon:** izlenme-tutuş verisi → kazanan hook'u çoğalt.
  → *veriyi yapıştır, analizi ben yaparım*

Gerçekçi zaman çizgisi (vakalardan): 1-2 hafta 50-500 izlenme; 3-6 haftada
ilk vural; 8-12 haftada istikrar. Kadans: 3-5 post/hafta yeterli.

## 4) Tenis nişi — DropVolley'in eli zaten güçlü

En hızlı büyüyen format **etkileşimli senaryo/quiz** ("What's the right
shot?" → yorumda oylat → doğruyu açıkla). Etkileşimli içerik statikten
~%52.6 daha çok etkileşim (rohringresults — directional). **Bu format
uygulamanın ta kendisi** — quiz ekran kayıtları doğal içerik.

Çalışan açılar:
1. "What's next?" senaryo anketi (app diyagramı + 3 şık, cevap yorumlarda)
2. Drill/teknik kısa anlatım + telestrasyon
3. "Rate my forehand" tarzı etkileşim (kullanıcı videosu + yorum)
4. Padel/pickleball crossover ("iki sporda da doğru karar bu mu?")
5. Kulüp oyuncusu mizahı / relatable anlar

Örnek hesaplar: @thetennisfox (39k, mizah+teknik), @prestons.playbook
(22k, drill eğitimi), the.tennis.coach (TikTok, hızlı kesim driller).

## 5) Erişimi öldürenler (yapma listesi)

1. **Filigranlı cross-post** (TikTok logosu Reels'te → Explore'dan dışlanma)
2. **Ticari hesapta lisanssız müzik** (bot taraması; Meta Sound Collection
   yalnız Meta'da geçerli)
3. **Engagement bait** ("beğen/yorum yaz" dilenciliği — platform cezası)
4. **Aşırı repost** (IG orijinallik önceliği; 30 günde 10+ repost = öneri
   dışı)
5. **Reklamlarda AI-görsel beyanı atlamak** (Meta reddediyor; EU AI Act
   Ağu 2026)
- Organik içerikte gerçekçi sentetik görüntü → etiketle; ekran kaydı +
  gerçek app görüntüsü için etiket derdi yok (bir avantaj daha).

## 6) Bu oturumda hazır olan üretim araçları

- **Bağlı (hemen kullanılabilir):** medya MCP'si — `generate_video`,
  `generate_image`, `generate_audio`, `shorts_studio_create`,
  `virality_predictor`, `dubbing`. (Deneysel; ekran-kaydı hattı asıl
  öneri, bunlar B-roll/ses için yedek.)
- **OAuth isteyenler (istersen claude.ai → Connectors'tan yetkilendir):**
  Canva, Similarweb, Amplitude, HubSpot vb. — zorunlu değil.
- **Repo'daki hat:** `build_slides.py` (carousel), `simctl recordVideo`
  (ham klip), captions.md şablonu.

## 7) DropVolley için 10 hazır hook (EN)

Reels (ekran kaydı üstüne overlay):
1. "You don't lose because of your forehand." *(contrarian — carousel'de de
   kullanımda)*
2. "This 20-second habit wins more matches than an hour of drills."
3. "POV: you finally know WHY you lost." *(merak + relatable)*
4. "Club players get this wrong 9 times out of 10." *(spesifik + merak)*
5. "Stop practicing your strengths." *(pattern interrupt)*
6. "Your doubles team has a blind spot." *(1.0.2 lansmanıyla uyumlu)*
7. "I asked an AI coach why I keep losing to the same guy." *(hikâye)*
8. "The right shot here isn't what you think." *(quiz senaryo formatı)*
9. "Rate your tennis IQ in 5 questions." *(challenge)*
10. "Watch what happens when you log a match by voice." *(demo/verim)*

İlk 5 Reel planı: (1) #8 hook'la quiz senaryosu ekran kaydı; (2) #6 ile
doubles rapor demo; (3) #10 ile sesli maç kaydı demo; (4) #1 statik hook →
app tur; (5) #9 challenge + yorum CTA'sı ("skorunu yaz").
