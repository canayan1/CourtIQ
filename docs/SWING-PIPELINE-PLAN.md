# Swing Pipeline — Detaylı Uygulama Planı (9 Tem 2026)

Araştırma temeli: [SWING-ANALYSIS-RESEARCH.md](SWING-ANALYSIS-RESEARCH.md).
Karar: video→VLM tek başına güvenilmez → deterministik pipeline'a kademeli geçiş.
**Can'ın video arşivi (Instagram klipleri + saatlik maç kayıtları) planın merkezinde:**
hem değerlendirme seti (bench) hem model eğitim verisi oradan çıkacak.

---

## Veri stratejisi — arşiv iki işe ayrılır

| Kaynak | Kullanım | Neden |
|---|---|---|
| **Instagram klipleri** (kısa, çekim kalitesi yüksek) | ① Bench/eval seti ② eğitim verisi | Tek vuruş/kısa dizi, iyi kadraj — etiketlemesi hızlı |
| **Saatlik maç videoları** | Vuruş MADENİ: ses-impact ile otomatik 3-5 sn'lik aday kliplere bölünür → hızlı etiketleme → eğitim verisi | Bir saatlik maçta 300-600 vuruş var; elle kesmek imkânsız, otomatik kesim bedava |

Saatlik videolar Gemini'ye ASLA bütün gitmez (maliyet + güvenilirlik); sadece madencilik girdisi.

---

## FAZ 0 — Bench: "izlesin-yorumlasın, ben eleştireyim" döngüsü  *(benim iş: ~1 gün)*

Can'ın istediği döngü, aynı zamanda her fazın ölçüm altyapısı.

**Ne kuruyorum — `tools/swing-bench/`:**
1. `run.ts` (Deno): klasördeki videoları alır, **prod'daki edge fonksiyonunun birebir prompt
   mantığıyla** (aynı kod import edilir) doğrudan Gemini'ye gönderir → çıktılar `results.json`.
   - Edge'i bypass etme sebebi: günlük kullanım kapları + prod kirletmemek. Anahtar: lokal
     `.env` içinden `GEMINI_VIDEO_API_KEY` (Can girer, repoya girmez, ekrana basılmaz).
   - Maliyet emniyeti: `--limit N` + koşu başına ~$1 üst sınır (Flash ~$0.008/klip).
2. `review.html`: lokal sayfa — solda video oynar, sağda AI çıktısı, altında eleştiri formu:
   - Vuruş tipi doğru mu? (E/H + doğrusu ne)
   - Sayım doğru mu? (E/H + gerçek sayı)
   - Yorum kalitesi 1-5 + serbest not ("toss yorumu uydurma", "dirsek tespiti isabetli"...)
   - Kayıt → `verdicts.json`
3. Çıktı: **baseline doğruluk raporu** (bugün gerçekte % kaç?) + Can'ın eleştirileri =
   ground-truth etiketler + prompt/rubrik iyileştirme girdisi + **regresyon seti**
   (her fazdan sonra AYNI set yeniden koşulur → iyileşme sayıyla görünür).

**Can'ın işi:** videoları klasöre koymak + klip başına ~1 dk eleştiri (20-30 klip yeter başlangıç).

## FAZ 1 — Deterministik sayım + impact kareleri + çekim rehberi  *(günler)*

Sayma rezaletini bitiren faz.

1. **Ses-impact sayımı (app içi):** Rally Cam'in `AudioImpactDetector`'ı (band-pass 100Hz-3kHz
   + adaptif eşik) video **dosyasının** ses izine uyarlanır (`AVAudioFile` offline okuma).
   → Tekrar sayısı DSP'den gelir; "I can see N forehands" satırındaki N ölçülmüş değer olur,
   prompt'a "count is measured, do NOT count" kuralı girer.
2. **Impact-merkezli kareler:** `AVAssetImageGenerator` her impact'in t−0.5s…t+0.3s aralığından
   8-12 kare çeker → edge'e video YERİNE zaman damgalı kareler gider (temas anı artık kesin
   görülüyor; bugün 5fps örnekleme temas anını kaçırıyor). Maliyet: ~3k token ≈ $0.001-0.01.
3. **Çekim rehberi (app içi):** vuruş tipine göre kadraj kartı — groundstroke=YAN açı (dik,
   3-5 m, tüm vücut+raket), servis=arkadan/yüksek; tek vuruş tipi; 10-30 sn; 60 fps önerisi.
   Uygunsuz video (çok uzun / çok kısa) analizden önce uyarı alır.
4. **Edge mikro-yaması:** tek-vuruş prompt'undan "kaç tekrar" isteği çıkar (deploy onayıyla).
5. **Doğrulama:** bench yeniden koşulur → sayım doğruluğu hedef ~%100 (ses net ise).

## FAZ 2 — Vision pose: ölçülmüş biyomekanik  *(1-2 hafta)*

1. Impact pencerelerinde `VNDetectHumanBodyPose3DRequest` (iOS 17+, cihazda, $0) →
   iskelet dizileri.
2. **Checkpoint metrikleri** (deterministik hesap): unit turn açısı, temas-önde (bilek vs kalça),
   low-to-high yörünge, bitiş yüksekliği, diz fleksiyonu, taban genişliği; serviste trophy
   (~65° ön diz), impact (~111° omuz, ~30° dirsek) referans bantları (Frontiers 2024).
3. Edge'e SAYILAR gider → LLM yalnızca ölçümden koçluk yazar → uydurma fiziken imkânsız.
   Skor = deterministik rubrik (LLM skoru "yorumlar", üretmez).
4. Bench: Can pose ölçümlerinin isabetini eleştirir (açı yorumları gerçekle uyuşuyor mu).

## FAZ 3 — Kendi modelimiz: Create ML Action Classifier  *(2-4 hafta, veriye bağlı)*

1. **Madencilik aracı (`tools/stroke-miner/`, benim iş):** saatlik videoları ses-impact ile
   3-5 sn'lik aday kliplere böler (ffmpeg), `candidates/` klasörüne yazar.
2. **Hızlı etiketleme aracı (benim iş):** lokal sayfa/script — klip oynar, Can tek tuşla
   etiketler: `F`orehand `B`ackhand `S`ervis `V`olley `O`verhead `X`=çöp. 500 klip ≈ 1-2 saat.
3. **Hedef veri:** sınıf başına 50-80 klip, **çeşitlilik önemli** (farklı oyuncular/stiller —
   Apple'ın açık tavsiyesi). Arşiv ağırlıkla Can ise: kulüpten/öğrencilerden ek çekim
   (yan açı, 60fps) — bir hafta sonu yeter. THETIS yalnızca prototip (ticari lisans belirsiz).
4. **Eğitim:** Create ML Action Classifier (2 sn pencere @30fps); script'lenir → "Train"
   tek komut. Mac'te dakikalar, $0.
5. **Entegrasyon (benim iş):** `.mlmodel` app'e; Vision keypoint → sınıflandırıcı → vuruş
   etiketi cihazda. Mixed-session güvenilir şekilde GERİ GELİR; "on-device AI" iddiası
   copy'ye geri yazılır.
6. Bench: sınıflandırma doğruluğu ölçülür (hedef %85-95+, yan-açı kısıtıyla).

---

## Can'ın yapacakları (toplamı: birkaç saat + bir hafta sonu çekim)

- [ ] **Şimdi:** videoları Mac'te tek yere topla — önerilen: `~/TennisVideos/instagram/` +
      `~/TennisVideos/matches/` (AirDrop/iCloud). Kabaca söyle: hangi açılar, hangi vuruşlar var.
- [ ] **Faz 0:** 20-30 klip için eleştiri turu (~30 dk) — review.html üzerinden.
- [ ] **Faz 1-2 sonrası:** 15-30 dk'lık bench eleştiri turları (her faz için bir tur).
- [ ] **Faz 3:** etiketleme oturumu (~1-2 saat, tek tuşlu araçla) + eksik sınıflar için
      ek çekim (yan açı, 60fps, farklı oyuncular — kulüpte bir hafta sonu).
- [ ] İçerikte başka insanlar varsa kullanım senin kararın (içerik sahibi sensin);
      model verisi cihaz dışına çıkmaz, eğitim tamamen lokal.

## Karar kapıları

1. Faz 0 baseline → Faz 1 önceliklerini netleştirir (sayım mı, sınıflama mı daha kırık).
2. Faz 1 sonrası bench → tek-vuruş modu "dürüst ve değerli" seviyesine geldi mi?
   (1.0.3 için yeterlilik kararı burada.)
3. Faz 2 sonrası → skor rubriği kullanıcıya gösterilecek kadar sağlam mı?
4. Faz 3 go/no-go → etiketli veri sayısı + sınıf dengesi yeterli mi (50+/sınıf)?

## Maliyet özeti

Bench koşusu ~$0.30-1 (limitli) · Faz 1 analiz ~$0.003-0.01 · Faz 2 ~$0.001-0.005 ·
Faz 3 eğitim+çıkarım $0 · Ek çekim: $0 (kort + telefon). Hepsi mevcut breaker altında.
