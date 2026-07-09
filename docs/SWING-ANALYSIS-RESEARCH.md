# Swing Analysis — Derin Araştırma (9 Tem 2026)

**Soru:** Swing analizi endüstride/akademide nasıl doğru yapılıyor? Modeli tune edebilir miyiz,
nasıl, hangi maliyetle? Çekim açısı ve video uzunluğu ne kadar önemli? Hangi kural setine göre?

**Bağlam:** Bizim mevcut mimari = video → Gemini (Flash/Pro) → koçluk metni.
Yaşanan: uydurma servis analizi (düzeltildi), yanlış vuruş sınıflama (Pro'da bile),
tek-forehand videosunda bile yanlış tekrar sayımı. Kullanıcı tatmin değil.

---

## 1. KÖK TEŞHİS — sorun prompt değil, paradigma

Video-LLM'ler **ince-taneli hareket algısında yapısal olarak zayıf**. Bu bizim gözlemimiz değil,
ölçülmüş literatür:

- **TemporalBench** (arXiv 2410.10818): ince-taneli zamansal anlama testinde GPT-4o
  **%38.5** doğruluk — insanla arasında ~30 puan uçurum.
- **TimeBlind** (arXiv 2602.00288): statik içerik aynı olup **sadece hareket dinamiği**
  farklı olan video çiftlerinde **GPT-5 ve Gemini 3 Pro dahi ayırt edemiyor**.
  → Bizim vakamız birebir bu: forehand / backhand slice / smaç — statik görüntü benzer,
  fark harekette. Model "görmüyor", tahmin ediyor.
- **Kare örnekleme matematiği:** 5 fps'te ~1 sn'lik swing = 4-6 kare; temas anı (~5 ms)
  neredeyse hiçbir zaman örneklenmiyor. Seyrek karelerden tekrar saymak = tahmin →
  tek vuruşluk videoda bile yanlış sayım. **Daha iyi prompt bunu düzeltmez; saymayı
  modelden almak düzeltir.**

## 2. ENDÜSTRİ NASIL YAPIYOR — kimse ham video→VLM kullanmıyor

| Ürün | Mimari | Zorunlu setup |
|---|---|---|
| **SwingVision** | Cihazda CV: top takibi + oyuncu takibi + pose; 500M+ vuruşla eğitilmiş kendi modelleri | Fence-mount, baseline arkası, ≥1.4-2 m yükseklik, tüm kort kadrajda |
| **OnCourtAI** (bizim ölçekte rakip) | Tek klip → 20+ vücut noktası (pose) → vuruş tipi tespiti → koçluk metni; "30 sn videoda 30.000 ölçüm" | **Yan açı zorunlu**, ≥30 fps, tripod/arkadaş |
| **Tennis AI 2.0** | 107 maddelik biyomekanik kontrol listesi + 100 üzerinden skor + pro karşılaştırma | Kontrollü tek vuruş klipleri |
| **SportAI** | Tek telefon videosundan 3D biyomekanik model | Standart telefon, kontrollü açı |
| **OnForm** | Otomatik analiz YOK — koça slow-mo + çizim aracı | — |

Ortak desen: **(a) kısıtlı/kanonik çekim açısı, (b) pose estimation, (c) eğitilmiş küçük
klasifikatör, (d) kural tabanlı biyomekanik ölçüm; LLM varsa yalnızca ölçülmüş gerçeklerin
ÜZERİNE dil katmanı.** Hiçbiri saymayı/sınıflamayı generatif modele bırakmıyor.

## 3. AKADEMİK DOĞRULAMA — önerilen pipeline yayınlanmış durumda

- **"Talking Tennis"** (arXiv 2510.03921): THETIS verisinde CNN-LSTM ile vuruş tanıma →
  eklem açıları/uzuv hızları/kinetik zincir çıkarımı → **LLM koçluk dilini bu ölçülmüş
  özelliklere dayandırıyor**. Birebir bizim hedef mimari.
- **Multi-Task Tennis, MediaPipe Pose** (arXiv 2606.15992): 33 landmark → 564K parametreli
  minik transformer → **%83.7 vuruş-tipi doğruluğu**; oyuncular-arası genelleme %82.9.
  **Ablation kritik: metrik dünya koordinatları yerine görüntü-düzlemi kullanılınca
  %83 → %47'ye düşüyor** → geometri/açı tutarlılığı doğruluğun ana belirleyicisi.
- **CNN-BiLSTM hibritleri**: THETIS'te ~%96.7'ye kadar raporlanmış.
- **THETIS veri seti**: 1.980 RGB + 8.374 iskelet dizisi, **12 vuruş sınıfı**, 55 denek
  (31'i başlangıç seviyesi!). Lisans: **araştırma amaçlı serbest; ticari belirsiz** →
  prototip/benchmark için kullan, üretim modelini **kendi verimizle** eğit.

## 4. "MODELİMİZİ TUNE EDEBİLİR MİYİZ?" — evet ama iki farklı yol var

### Yol A — Gemini'yi fine-tune etmek (Vertex AI SFT)
- **Resmî olarak mümkün ve video destekli**: örnek başına **1 video**, HIGH/MEDIUM
  çözünürlükte **≤5 dk** (LOW'da ≤20 dk); limit aşan örnekler düşülür, >%10 düşerse iş
  hata verir.
- Veri ihtiyacı: yüzlerce-binlerce **etiketli** klip. Eğitim maliyeti: video token'ları ile
  ~10-30M eğitim token'ı ≈ **~$30-120/koşu** (≈$2-4/1M eğitim token'ı, üçüncü-taraf rakam —
  ucuz sayılır). Tune edilmiş modelin çıkarım fiyatı taban modelle aynı.
- **AMA:** (1) Vertex'e taşınma gerekir (şu an basit Gemini API'deyiz), (2) sonuç yine
  kara-kutu bir VLM — TimeBlind bulgusu mimari: **seyrek kare örneklemesinden doğan
  hareket-körlüğünü SFT çözmez**, sınıflama önyargısını/format uyumunu iyileştirir,
  sayma güvenilirliğini garanti etmez. → **Sayma/sınıflama sorunu için yanlış araç.**

### Yol B — KENDİ modelimizi eğitmek (asıl "tune" fırsatı) ✅
**Create ML Action Classifier** (Apple, pose-dizisi tabanlı):
- Veri: **sınıf başına ~50 video** (Apple'ın resmî önerisi), 2 sn'lik pencere @30fps.
  Ekipte antrenörler var → bir hafta sonu çekimle 6 sınıf × 50-80 klip toplanır.
- Eğitim: kendi Mac'inde, dakikalar, **$0**. Çıkarım: cihazda, **$0**, offline.
- Beklenen doğruluk (literatür + kısıtlı yan-açı ile): **%85-95+**.
- Bonus: "on-device AI" iddiasını **gerçekten** kazanırız (App Store copy'ye geri koyarız)
  + mixed-session modu güvenilir şekilde geri gelir.

## 5. AÇI VE UZUNLUK NE KADAR ÖNEMLİ? — Açı: en büyük tek kaldıraç

**Açı (koçluk kaynakları + araştırma):**
- **Groundstroke** (FH/BH): **yan açı** — vuruş çizgisine dik, bel hizası, 3-5 m,
  tüm vücut + raket yolu kadrajda. Temas noktası, low-to-high yol, kilo transferi görünür.
- **Servis**: **arkadan/arkadan-yüksek** — hizalanma, toss, tempo; yan açı trophy/kol için.
- Tutarlı tek açı hem ML hem LLM doğruluğunu katlıyor (ablation: %83→%47).
  SwingVision ve OnCourtAI'ın ilk yaptığı şey açıyı ZORUNLU kılmak.
- **Bize çeviri:** kayıt ekranına vuruş-tipine göre "böyle çek" rehberi (diagram + onay),
  yanlış açıyı analizden önce yakala.

**Uzunluk:**
- Kısa klip = güvenilir analiz. İdeal **10-30 sn, tek vuruş tipi**, üst sınır ~60 sn.
- Maliyet doğrusal: Flash 5fps ≈ $0.0008/sn input. Uzun karışık ralli → segmentasyon
  problemi → yanlış sayım. Segmentasyonu ses (impact) çözer, LLM değil.

**fps:** Çekim 60 fps (mümkünse); insan gözü için 120/240 slow-mo lüks. Pose pipeline'ı
30-60 fps ile çalışır; Gemini'ye giden video zaten 5 fps örnekleniyor (sorunun kendisi).

## 6. KURAL SETİ — ölçülebilir biyomekanik checkpoint'ler (pose'dan hesaplanır)

**Servis** (Frontiers 2024 meta-analizi, ölçülmüş değerler):
| Checkpoint | Metrik | Referans |
|---|---|---|
| Trophy position | Gövde eğimi ~25°; ön diz fleksiyonu ~65° | 25.0±7.1° / 64.5±9.7° |
| Racket low point | Omuz dış rotasyonu ~130° | 130.1±26.5° |
| Ball impact | Omuz elevasyonu ~111°; dirsek fleksiyonu ~30° (tam uzanmaya yakın) | 110.7±16.9° / 30.1±15.9° |

**Forehand/Backhand** (koçluk çerçeveleri; hepsi keypoint'ten türetilir):
unit turn (omuz hattı rotasyonu ≥~80-90°) · raket topun altına düşer (bilek<dirsek) ·
temas ön kalçanın ÖNÜNDE (impact karesinde bilek-x > kalça-x) · low-to-high yol
(bilek yörünge eğimi) · dengeli yüksek bitiş (bilek karşı omuz üstü) · taban genişliği
(ayak bileği açıklığı > omuz) · yüklenmede diz fleksiyonu ~120-140°.

→ Her checkpoint deterministik PASS/FLAG; skor = ağırlıklı rubrik; **LLM yalnızca bu
ölçümleri koçluk diline çevirir** (Talking Tennis mimarisi). Uydurma fiziken imkânsızlaşır.

## 7. MALİYET KARŞILAŞTIRMASI (analiz başına)

| Yaklaşım | Maliyet | Güvenilirlik |
|---|---|---|
| Bugün: video→Flash 5fps | ~$0.008 | Zayıf (sayım/sınıf hatalı) |
| Bugün: video→Pro | ~$0.03 | Zayıf (denedik, aynı hata sınıfı) |
| **Faz 1**: ses-sayım + impact-merkezli 8-12 kare→Gemini | **~$0.003-0.01** | Sayım deterministik ✅ |
| **Faz 2**: Vision pose (cihaz, $0) + metin-LLM | **~$0.001-0.005** | Ölçüm deterministik ✅ |
| **Faz 3**: Create ML sınıflandırıcı (cihaz) | **$0 çıkarım** | %85-95+ sınıflama ✅ |
| Gemini video SFT | ~$30-120/eğitim + Vertex taşınması | Belirsiz (hareket-körlüğü kalır) |

**Sonuç: doğru mimari bugünkünden hem güvenilir hem UCUZ.**

## 8. YOL HARİTASI (önerilen)

- **Hemen (edge, 1 satır):** tek-vuruş prompt'undan "kaç tekrar" isteğini çıkar —
  modele verdiğimiz en halüsinasyon-eğilimli görev. Vuruş tipini onaylasın, saymasın.
- **Faz 1 (günler):** (a) kayıt ekranına açı/uzunluk rehberi (yan açı, tek vuruş tipi,
  10-30 sn, 60 fps); (b) mevcut **AudioImpactDetector**'ı video ses izine uygula →
  tekrar sayısı DSP'den, "N forehand görüyorum" satırı ölçülmüş N ile; (c)
  AVAssetImageGenerator ile her impact etrafından 8-12 kare → Gemini'ye video yerine/yanında
  zaman damgalı kareler.
- **Faz 2 (1-2 hafta):** VNDetectHumanBodyPose3DRequest (iOS 17+) impact pencerelerinde →
  §6 checkpoint metrikleri cihazda → edge'e SAYILAR gider → LLM ölçümden koçluk yazar.
  Skor rubriği deterministik.
- **Faz 3 (2-4 hafta):** kendi verimizle Create ML Action Classifier → cihazda vuruş
  sınıflama → mixed-session geri gelir + "on-device" iddiası gerçek olur.
  (THETIS yalnızca prototip; üretim = kendi çekimlerimiz.)

## Kaynaklar
- TemporalBench: https://arxiv.org/abs/2410.10818 · TimeBlind: https://arxiv.org/pdf/2602.00288
- Talking Tennis (pose→CNN-LSTM→LLM): https://arxiv.org/pdf/2510.03921
- MediaPipe multi-task tennis: https://arxiv.org/pdf/2606.15992 · CalTennis: https://arxiv.org/html/2606.20542v1
- THETIS: https://github.com/THETIS-dataset/dataset · CVPR'13: https://openaccess.thecvf.com/content_cvpr_workshops_2013/W08/papers/Gourgari_THETIS_Three_Dimensional_2013_CVPR_paper.pdf
- Serve kinematics meta-analizi: https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2024.1432030/full
- SwingVision setup: https://swing.vision/guides/set-up-your-recording
- OnCourtAI: https://www.oncourtai.co.uk/ · OnForm: https://onform.com/
- Vertex video tuning: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/tuning/video
- Apple Action Classifier: https://developer.apple.com/documentation/createml/creating-an-action-classifier-model + WWDC20 10043
- Kamera açıları (koçluk): https://www.tennismethod.com/best-camera-angles-for-tennis-video-analysis/ · https://www.tennistechie.com/blog/2018/9/10best-practices-for-video-analysis
