# "Sıfırdan Kortta" — Beginner Tenis Öğrenme Rehberi · Tasarım
**11 Tem 2026 · Durum: ONAY BEKLİYOR · docs/TENNIS-CONTENT.md + CURRICULUM_MAP.md üstüne inşa**

## 1. Ne ve neden

Adım adım, tamamlanabilir bir **öğrenme yolu**: hiç tenis oynamamış (ya da 0-6 ay)
yetişkini ekipman seçiminden **ilk sosyal maçına** kadar taşır. Teknik + drill +
sosyal tenis + fizik/kuvvet + "nelere dikkat" tek omurgada.

**Stratejik yeri:** free katmanın taşıyıcı değeri. Freemium tezimiz "get better
free before you pay" — bugün free'de günlük tip + quiz + duvar var ama BAĞLAYICI
ANLATI yok. Path, Duolingo-tipi ilerleme psikolojisini (Wall vizyonundaki) free
tarafa getirir; premium'a köprüleri doğal yerlerde kurar (Coach'a sor, swing
checkpoint'i, duvar premium seviyeleri). Beginner = App Store'daki en büyük ve
en az sahiplenilmiş kitle (rakipler swing-odaklı intermediate'e oynuyor).

**Hedef kullanıcı:** yetişkin, sıfır/çok az deneyim, kortu-kulübü yabancı,
"nereden başlayacağımı bilmiyorum" diyen kişi. (Tennis Profile skill=Beginner
→ Home'da bu path hero olur.)

## 2. Tasarım ilkeleri

- **P1 · Her adım 5-20 dk ve tamamlanabilir.** "Bugün 1 adım" = streak katkısı.
- **P2 · Kortsuz da ilerlenir.** Ev/duvar/park adımları çoğunlukta; kort adımları
  işaretli. Ekipmansız başlangıç mümkün (U0'ın ilk yarısı koltuktan yapılır).
- **P3 · Göster, anlatma.** Her drill mevcut diagram/animasyon bileşenleriyle
  ("drills you can SEE" vaadi). Metin blokları kısa.
- **P4 · Ölç, iddia etme.** "Doğru yapıyor musun"u yalnızca ölçebildiğimiz yerde
  söyleriz (duvar sayacı, quiz skoru, tamamlama). Teknik doğruluğu iddia etmeyiz;
  isteyen swing analizine gönderilir (premium köprüsü, dürüst sınırıyla).
- **P5 · Güvenlik yetişkin gerçeğine göre.** 30-50 yaş, masa başı geçmişi olan
  gövde varsayılan; her fiziksel adımda yüklenme uyarısı + sağlık disclaimer'ı
  (Coach'taki sağlık duvarı kalıbı). Tennis elbow/omuz koruması müfredatın içinde,
  dipnotta değil.
- **P6 · Sosyal tenis birinci sınıf vatandaş.** Görgü kuralları, partner bulma,
  ilk sosyal maç — teknik kadar yer tutar (Can'ın açık isteği + rakiplerde yok).

## 3. Müfredat — 8 ünite (~55 adım, ~6-8 hafta doğal tempo)

Kaynak çerçeve: ITF Play+Stay/Tennis Xpress yetişkin progresyonu + LTA beginner
programları + docs/TENNIS-CONTENT.md bölge/heuristik omurgası. Her ünite:
adımlar → ünite sonu **checkpoint** (quiz motoru, beginner soru seti) → rozet.

**U0 · Korta Çıkmadan** *(kortsuz, ~5 adım)*
raket seçimi (grip ölçüsü, kafa boyu, hazır kordaj — "pahalı raket alma" dürüstlüğü) ·
ayakkabı/kıyafet · top türleri (yeşil nokta topun yetişkin beginner'a MEŞRU olduğu) ·
kort türleri + rezervasyon/kulüp ABC'si · 6 dk'lık dinamik ısınma rutini
(mobility_flows.json'dan) · ⚠️ dikkat: ilk haftalarda hacim, güneş/su, ağrı sinyalleri

**U1 · Raketle Tanış** *(ev/park, ~6 adım)*
continental & eastern grip (el fotoğraflı diagram) · ready position + split step ·
top hissi drilleri (raket üstü sektirme yer/hava, kenar sektirme) · yumuşak duvar
teması · 🧠 checkpoint: grip + hazır pozisyon quizi

**U2 · Forehand** *(duvar/kort, ~8 adım)*
gölge vuruş progresyonu (unit turn → drop → low-to-high → önde temas → yüksek bitiş —
swing COACHING_REFERENCE ile aynı dil) · drop-feed drilleri · duvar FH (WallDrill
pacer'ıyla, hedefli) · yaygın hatalar ("arming the ball", geç hazırlık) · 💪 fizik:
gövde rotasyonu + bacak itişi ev seti · 🎥 opsiyonel köprü: "FH'ini AI'a analiz ettir"

**U3 · Backhand** *(duvar/kort, ~7 adım)*
iki el/tek el kararı (beginner'a iki el önerisi + nedeni) · aynı progresyon ·
duvar BH · FH+BH dönüşümlü duvar drilli · 🧠 checkpoint

**U4 · Rally Kurmak** *(duvar+ilk partner, ~7 adım)*
kontrol>güç: net üstü pencere + derinlik · duvar rally hedefleri (5→10→20 ardışık;
sayaç premium'suz manuel, Rally Cam teaser) · footwork: split timing + toparlanma ·
**mini-tennis** (servis kutuları arası — İLK PARTNER ADIMI) · partner beslemeli
rally · 🧠 checkpoint: bölge kavramı (defense/neutral/offense'in bebek hali)

**U5 · Servis & Sayı** *(kort, ~7 adım)*
platform stance + ritim servisi (abartısız model; toss→yukarıda temas) · underarm
servisin sosyal meşruiyeti · servis kutusu hedef drilleri · puanlama: 15-30-40,
deuce, tie-break (quiz ile) · sayı başlatma ritüeli (kim servis atar, taraf seçimi) ·
🧠 checkpoint: puanlama + servis kuralları

**U6 · Sosyal Tenis** *(kulüp/sosyal, ~8 adım — bu ünite bizim farkımız)*
partner bulma kanalları (kulüp sosyal saatleri, gruplar, hitting partner görgüsü) ·
kort görgü kuralları derin: top toplama/iade, out-let çağrıları, skor söyleme,
bekleyene saygı, kortlar arası top · sosyal formatlar: Amerikan doubles, round
robin, cardio tennis · **ilk doubles**: pozisyonlar, "mine/yours", servis sırası ·
DropVolley doubles uyum köprüsü · ✅ görev-adımı: "bir sosyal etkinliğe katıl"
(kendin işaretle — dürüst self-report)

**U7 · İlk Maçın** *(kort, ~7 adım)*
maç öncesi rutin (mental check + nefes — mevcut özellik entegre) · beginner
taktiği = konsistens: derin-ortaya, rakibi koştur, hediye hata verme (TENNIS-CONTENT
heuristik 8/10'un beginner çevirisi) · skor tutma pratiği · centilmenlik/el sıkışma ·
maç sonrası: match log'a kaydet (mevcut özellik) + "ne öğrendim" · 🎓 MEZUNİYET:
Tennis Profile yeniden değerlendirme → improver yoluna teaser

**Paralel hat · 💪 Kuvvet & Sağlık** *(haftada 2, path'e serpiştirilmiş + Train'den erişilir)*
4 haftalık bloklar (training_programs.json'a `level: "beginner"` programı olarak):
alt gövde (squat/lunge progresyonu) · core anti-rotasyon (pallof, dead bug) ·
omuz sağlığı (band external rotation, scapular) · önkol/tennis elbow ÖNLEME
(eksantrik bilek) · hareketlilik (mobility_flows) · basit interval kondisyon.
Her seans 20-25 dk, ekipman: bant + kendi ağırlığı. ⚠️ her blokta sağlık notu.

**Paralel hat · ⚠️ "Nelere Dikkat" kartları** *(ünitelere gömülü)*
aşırı kullanım sinyalleri (dirsek/omuz/bel) · ağrıyla oynamama kuralı · ısı/güneş ·
yüzey değişimi · ekipman bakımı (kordaj, grip değişimi) · "haftada 2-3'ten fazla
artırma" hacim kuralı.

## 4. Mekanikler

- **İlerleme:** adım tamamla → XP + streak (ActivityManager'a yeni event türü) ·
  ünite checkpoint'i geç → rozet · path ekranında görsel ilerleme.
- **Kilit YOK (yumuşak sıra):** üniteler önerilen sırada ama kilitli değil —
  yetişkin öğrenci çocuk değil; "sıradaki önerilen adım" vurgusu yeter. (Duolingo
  mekaniği duvar CHALLENGE tarafında premium olarak yaşar; burada baskısız.)
- **Checkpoint quizleri:** mevcut quiz motoru + yeni `beginner` etiketli ~30 soru
  (puanlama, görgü, grip, bölge kavramı) — CURRICULUM_MAP hata-tipleriyle etiketli.
- **Görev-adımları (sosyal):** self-report onay ("katıldım") — dürüst, ölçüm iddiası yok.
- **Mezuniyet:** U7 sonu → profil yeniden testi; sonuç Home'a yansır.

## 5. Veri modeli (bundle JSON — tips/programs kalıbı)

`CourtIQ/Resources/Content/learn_path.json`:
```jsonc
{ "v": 1, "units": [ {
  "id": "u2-forehand", "icon": "figure.tennis", "title": "...", "titleTr": "...",
  "summary": "...", "summaryTr": "...", "checkpointQuizTag": "beginner-u2",
  "steps": [ {
    "id": "u2-s3-wall-fh", "kind": "drill",        // lesson|drill|social|fitness|safety|checkpoint
    "title": "...", "titleTr": "...", "estMinutes": 15,
    "location": "wall",                            // home|wall|court|club
    "equipment": ["racket", "balls"],
    "blocks": [
      { "type": "text", "en": "...", "tr": "..." },
      { "type": "diagram", "ref": "grip-continental" },      // mevcut diagram bileşenleri
      { "type": "wallDrill", "ref": "fh-steady-10" },        // WallDrill kütüphanesine köprü
      { "type": "checklist", "items": [ {"en": "...", "tr": "..."} ] },
      { "type": "timer", "seconds": 300 },
      { "type": "caution", "en": "...", "tr": "..." },       // ⚠️ kartı
      { "type": "featureLink", "target": "swingAnalysis" }   // premium köprüleri
    ] } ] } ] }
```
İlerleme: `LearnPathStore` (UserDefaults/SwiftData mevcut store kalıbı):
`completedStepIDs: Set<String>`, `unitBadges`, streak event'i.

## 6. UI (3 ekran, mevcut bileşenlerle)

1. **Path ekranı** — dikey yol: ünite kartları (ikon+ilerleme halkası), altında
  adım zinciri; "sıradaki adım" hero CTA. Clay/cream, FeatureTile/PressableCard
  dili. Giriş: Train'e kalıcı kart + skill=Beginner ise Home hero.
2. **Adım ekranı** — blok listesi (metin/diagram/checklist/timer/duvar-drill
  köprüsü/uyarı kartı) + "Tamamladım" CTA (+streak toast). Drill blokları
  WallSession pacer'ına deep-link.
3. **Ünite checkpoint** — mevcut quiz akışı, sonunda rozet + sonraki ünite kartı.

## 7. Freemium çizgisi

**Path'in tamamı FREE** (strateji: free hook + retention + "get better free"
vaadinin kanıtı). Premium dokunuşları doğal köprüler: adım içinde "Coach'a sor"
(seed'li) · U2/U3 sonunda "vuruşunu AI'a analiz ettir" · duvar CHALLENGE
seviyeleri/leaderboard (Duolingo vizyonu premium'da kalır). Path asla paywall'a
çarpmaz; köprüler işaretli ve atlanabilir.

## 8. Dürüstlük & güvenlik kuralları

- Teknik adımlarda "doğru yaptın" DEMEYİZ (ölçmüyoruz) — "checklist'i tamamladın"
  deriz. Ölçüm iddiası yalnızca ölçülen yerde (duvar sayacı, quiz, swing analizi).
- Fizik içerik: eğitim amaçlı genel bilgi disclaimer'ı + "ağrı = dur" kuralı her
  fitness adımında; tıbbi iddia yok. (Sağlık duvarı kalıbı yeniden kullanılır.)
- Pro istatistikleri beginner'a benchmark diye sunulmaz (TENNIS-CONTENT kuralı).
- İçerik kaynakları: ITF/LTA/USTA çerçeveleri "ilhamla yazılmış özgün içerik" —
  logo/isim iddiası yok, telif metni kopyalanmaz.

## 9. Yapım fazları

- **P1 (çekirdek, ~2-3 gün):** model + `learn_path.json` U0-U2 içeriği (TR/EN) +
  Path & Adım ekranları (text/checklist/diagram/caution/timer blokları) + ilerleme
  store + streak entegrasyonu + Train kartı. → Sim QC + build.
- **P2 (+2-3 gün):** U3-U5 içerik + duvar-drill köprüsü + checkpoint quiz seti
  (~30 beginner sorusu) + beginner fitness programı (training_programs +
  mobility köprüsü) + Home hero (skill=Beginner).
- **P3 (+2 gün):** U6-U7 (sosyal + maç) + doubles/mental-check/match-log köprüleri +
  rozetler + mezuniyet→profil yeniden testi + ⚠️ kart seti tamamı.
- İçerik yazımı benim işim (TENNIS-CONTENT çerçevesinden, TR+EN birlikte);
  Can editoryal onay (özellikle U6 sosyal görgü — koç gözü).

## 10. Açık kararlar (Can)

- K1 · İsim: **"Sıfırdan Kortta" / "Zero to Court"** mi, "Learn Tennis" sade mi?
- K2 · Path'in tamamı free onayı (öneri: evet — §7 gerekçesi).
- K3 · Sosyal görev-adımlarında self-report yeterli mi (öneri: evet, dürüst).
- K4 · 1.0.4 hedefi mi, sonraki büyük sürüm mü?
