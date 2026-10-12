# Clips — "bu vuruşta ne görüyorsun?" (ürün kurgusu, v0)

*12 Ekim 2026. Kaynak: `reports/Video quiz platformu fizibilite kurgusu.md` ve
`reports/DropVolley pazar ve viral büyüme araştırması.md`. Bu doküman karar
dokümanıdır; §11'deki sorular cevaplanmadan kod yazılmaz.*

## 00. Vizyon (Can, 12 Eki)

> "Bu aslında koçların öğrencileriyle, kulüpteki insanların arkadaşlarıyla
> interact etme aracı olacak. DropVolley sayesinde güvenilir bir ortamda,
> AI ile kuvvetlendirilmiş şekilde, bir platform içinde şeffaf yapılmasını
> sağlamak istiyorum."

**İlke (Can, 12 Eki): bu işte mutlak doğru yok.** Koç, arkadaş ve AI üç
*bakış*tır; hiçbiri "cevap anahtarı" değildir, hiçbiri diğerini "yenmez".
Ürün bir yarışma değil, **geri bildirim içeren toplumsal analiz dayanışması**:
bir vuruşa çok göz bakar, bakışlar yan yana konur, fark öğretir. Bu
dokümanda "doğru", "anahtar", "kazanan", "yendi" kelimeleri bilinçli olarak
kullanılmaz; "referans", "bakış", "uyum", "fark" kullanılır.

Bunun kurguya etkisi: **atomik birim "arkadaş grubu" değil, "koç + öğrencileri"**.
Kalabalık değil koç merkezde; AI hakem değil koçun aleti; şeffaflık = iki
taraf da aynı veriyi görür; güven = doğrulama + arkadaş-grubu gizliliği +
feed'sizlik. Ücretli koç incelemesi, yabancı pazarı olmaktan çıkıp koç–öğrenci
ilişkisinin içindeki bir adım olur. Bkz. §0 ve §6.

## 0. Can'ın kararları (12 Eki)

1. **Faz 1 sadece arkadaşlar.** Klip, yükleyenin arkadaşlarına gider; sonuç
   yükleyenin profiline eklenir. Keşfet/açık feed **Faz 2**.
2. **Koçlara yıldız.** Doğrulanmış tenis koçlarının cevapları ayrı sayılır ve
   ayrı gösterilir; koç ile oyuncu görüşü arasındaki *fark* görünür olur.
3. **Son soru: "Bu oyuncunun WTN / UTR'si kaç?"** Referansı yükleyenin
   kendi beyanı — bir hakikat değil, kişinin kendi sayısı.

Bu üçü, araştırmanın en zor iki sorusunu çözüyor:

- *Doğruyu kim bulur?* → Kimse. Koç bakışı **referans** bakıştır (ayrı
  gösterilir, ağırlığı yüksektir) ama "doğru" değildir; arkadaş bakışı
  "arkadaşların gördüğü"dür. Koç oylarının ayrı tutulması, bakışlar arası
  *uyumu* ölçmeyi mümkün kılar — kalibrasyon için yeter, hakikat iddiası
  gerektirmez.
- *Apple yaş sınıfı?* → Arkadaş grubu, beğenisiz, feed'siz = "UGC + mesajlaşma",
  **4+** kalır. Açık feed 13+ ve yaş beyanı API'si ister — Faz 2'nin bedeli bu.

## 1. Oyun döngüsü

### Yükleyen (30 saniye)
1. Coach sekmesi → **Klip paylaş** → Fotoğraflar'dan seç (`PHPicker`, izin
   sorusu yok) ya da swing analizi için zaten çekilmiş klibi kullan.
2. Cihazda kırp (≤ 12 sn) ve sıkıştır (720p, ~4 MB). Sunucu transcode yok.
3. Vuruş türünü seç (forehand / backhand / servis / vole). Zorunlu tek etiket.
4. İsteğe bağlı: **puanım** (WTN 40→1 ya da UTR 1→16.5) — gizli, sadece 4.
   soruyu puanlamak için. Puanı yoksa seviye bandı (3.0 / 3.5 / 4.0…).
5. Onay: "Karedeki herkes razı · 16+ · yüz bulanıklaştırma (Faz 1.5)".
6. Kimlere: arkadaş listesi (hepsi seçili) + varsa antrenman grubu.

### Cevaplayan (45 saniye, uygulama içinde)
Klip döngüde oynar. Oylar **cevap verilene kadar gizli** (sürü etkisi önlemi).

| # | Soru | Tip | Referans (doğru değil) |
|---|---|---|---|
| Q1 | En kritik sorun ne? | footwork · teknik · karar · **"bu açıdan görünmüyor"** | koç bakışı, yoksa yok |
| Q2 | Tam olarak ne? | Q1'e bağlı 4–6 seçenek (ör. teknik → geç hazırlık / bilek / raket yüzü / temas noktası / bitiriş) | koç bakışı |
| Q3 | Hangi anda? | videoda dokun | koç zaman damgalarının medyanı ± 0,3 sn |
| Q4 | Bu oyuncu kaç? | WTN/UTR kaydırıcı (ya da seviye bandı) | **yükleyenin beyanı** (tek nesnel referans) |

"Bu açıdan görünmüyor" seçeneği zorunlu: koç panelindeki "—" ile aynı
dürüstlük; yanlış açıdan çekilmiş klipte kalabalığı tahmine zorlamıyoruz.

### Sonuç (yükleyen görür)
```
Forehand · 7 arkadaş, 2 koç cevapladı

⭐ Koçlar         2/2  teknik → geç hazırlık   @1.8 sn
👥 Arkadaşlar     4/7  teknik · 2/7 footwork · 1/7 karar
                       geç hazırlık 3 · bilek 1          @2.1 sn (medyan)

Seviye tahmini    arkadaşlar ortalama WTN 27 · koçlar 24 · sen 25
```
Koç varsa koç satırı üstte, "⭐ koç bakışı" olarak işaretli; "doğru",
"anahtar" kelimeleri hiçbir ekranda geçmez. Her cevaplayan kendi bakışını
koçlarınkiyle yan yana görür: **"Koçlarla uyum: 2/3."** Uyumsuzluk hata
değil, *fark*tır — ekran "yanlış" demez, "koçlar başka bir şey gördü" der.

### Paylaşım kartı (spoiler'sız)
Donmuş kare + "7 arkadaşım bu forehand'de 3 farklı şey gördü — sen ne
görüyorsun?" + 6 haneli grup kodu + uygulama adı. Stories'e görsel, WhatsApp'a
evrensel link (`samosfi.com/k/<kod>`): yüklemeyen tarayıcıda klibi izleyip
Q1'i cevaplar, sonra "arkadaş ol ve gerisini gör".

## 2. İki ayrı hesap: koç ve oyuncu

- Her oy satırı `rater_kind ∈ {coach, player}` taşır; kind **oy anında**
  dondurulur (sonradan koç olmak eski oyları değiştirmez).
- **Gösterim eşikleri:** oyuncu görüşü ≥ 3 oyda, koç görüşü ≥ 1 koçta görünür.
  Altında "henüz yeterli cevap yok".
- **Fark göstergesi:** klip bazında ve toplamda — "Bu klipte arkadaşlar ve
  koçlar farklı şey gördü" rozeti; aylık "oyuncular koçlarla %X uyuştu"
  istatistiği (araştırmanın beklentisi: Q1'de yüksek, Q2'de düşük — bunu
  ölçmek başlı başına içerik).
- **Göz puanı (rater için):** koç bakışı olan kliplerde Q1–Q3 uyum oranı — "koçlarla ne kadar aynı görüyorsun", "ne kadar doğru görüyorsun" değil.
  Üçüncü bir "IQ" sayısı **üretilmez**; göz puanı Tennis IQ'nun içine
  "video" kategorisi olarak akar (profildeki iki IQ sorunu büyümesin).
- Koç cevapları ağırlıklandırmada kullanılır; oyuncu ağırlığı *sadece* koç
  bakışı olan kliplerdeki geçmiş uyumdan hesaplanır, asla kalabalıkla uyumdan
  (Community Notes tuzağı).

## 3. Koç yıldızı — doğrulama şart

Ev kuralı: sahte sosyal kanıt yok. Yıldız **sadece doğrulanmış** koça verilir.

- Başvuru: uygulamada "Koçum" → sertifika fotoğrafı (ITF / PTR / USPTA / LTA /
  TTF / FFT) + ad soyad + kulüp → `coach_review_coaches` tablosuna
  `credential_type`, `credential_ref`, `verified_at`, `verified_by` alanları
  eklenir; Can elle onaylar (Faz 1'de günde <5 başvuru beklenir).
- Doğrulanmamış koç: yıldız yok, oyları `player` sayılır, "koçum" ibaresi
  gösterilmez. "Beklemede" rozeti bile yok — belirsizlik satılmaz.
- Koçun kazandığı: ⭐, cevapları öne çıkar, kendi öğrencilerinin kliplerinde
  referans sayılır, profilinde "N klibe koç gözüyle baktı"; Faz 2'de keşfet
  dağıtımı ve ücretli inceleme kuyruğuna otomatik giriş.
- Koç cevabı **teşhis** değil **gözlem**dir: koç da aynı çoktan seçmeliyi
  doldurur, serbest metin yok (Faz 1). Tıbbi/sakatlık ifadesi için alan yok.

## 4. WTN / UTR tahmini

Bu, koç bakışına ihtiyaç duymayan tek soru ve en paylaşılabilir sonuç
("arkadaşların seni 4.5 sandı, sen 4.0'sın").

- Yükleyen puanını girer (isteğe bağlı). Saklanır: `clips.declared_rating`
  (`system ∈ {wtn, utr, band}`, `value`), **yalnız yükleyen ve sunucu görür**;
  RLS ile cevaplayanlara kapalı. Cevaplayanlar klibi gördükten sonra tahmin
  eder; yükleyen sonuçta dağılımı ve ortalamayı görür, dilerse kartta paylaşır.
- Puanlama: |tahmin − beyan|; WTN için ±3, UTR için ±0,75 "isabet" sayılır.
  Göz puanına Q4 isabeti ayrı bir kalem olarak girer.
- Puanı olmayan yükleyen seviye bandı girer; bant tahminleri düşük ağırlıklı
  ("beyan" kalitesi daha düşük).
- Doğrulama (Faz 1.5): WTN profilleri halka açık — yükleyen profil linkini
  eklerse "doğrulanmış puan" işareti; Can elle bakar.
- Çerçeve: soru vuruşun seviyesiyle ilgili, kişiyle değil. Apple 1.2'nin
  "gerçek kişilerin nesneleştirilmesi (hot-or-not)" yasağından uzak durmak
  için: görünüm/beden/yaş hakkında hiçbir soru, hiçbir serbest metin, ve
  tahmin sonucu **yalnız yükleyene** gösterilir (cevaplayanlar birbirinin
  tahminini görmez).

## 5. Profil

Profile üç parça eklenir (mevcut "Three pillars" bölümünün altına):

1. **Kliplerim** — her klip: donmuş kare, cevap sayısı, koç var/yok, fark
   rozeti. Dokun → sonuç ekranı.
2. **Gözüm** — koçlarla uyum % (Q1/Q2/Q3 ayrı), seviye tahmini isabeti,
   "N klibe baktın". Tennis IQ'nun video kategorisi olarak.
3. **Koç yıldızı** (doğrulanmışsa) + "öğrencilerim" listesi (Faz 1.5).

Arkadaşların profilinde görünen tek şey: koç yıldızı ve "N klibe baktı".
Kimsenin klibi arkadaşının profilinde listelenmez (Faz 1).

## 6. Arkadaş grafı

- `doubles_partnerships`'in 2 kişilik kod modeli genelleştirilir:
  `friendships (user_a, user_b, status, created_at)` karşılıklı; davet =
  6 haneli kod ya da `samosfi.com/f/<kod>` evrensel link (AASA'ya `/f/*` ve
  `/k/*` eklenir). Rehber erişimi **istenmez** (Apple 5.1.2).
- Başlangıçta arkadaş tavanı **20** (Duolingo 5 / Locket 20 aralığı); Faz 1'de
  büyütülmez.
- **Gruplar** (Faz 1.5): koç ya da kaptan grup açar, üyeler koda katılır;
  klip gruba da gönderilebilir. Pilotun birimi zaten bu (antrenman grubu /
  box-league).

## 7. Veri modeli (Supabase)

```
clips                 id, owner, stroke, storage_path, poster_path, duration_ms,
                      visibility ∈ {friends, group, public}  -- Faz 2 için şimdiden
                      declared_rating_system, declared_rating_value (RLS: owner)
                      status ∈ {active, reported, removed}, created_at, purge_at
clip_recipients       clip_id, user_id                       -- kime gönderildi
clip_votes            clip_id, rater, rater_kind ∈ {coach, player},
                      q1, q2, q3_ms, q4_guess, answered_at   -- (clip, rater) unique
clip_reports          clip_id, reporter, reason, created_at   -- Apple 1.2
friendships           user_a, user_b, status
coach_review_coaches  + credential_type, credential_ref, verified_at, verified_by
```
- Depolama: özel bucket `clips`, `<owner>/<clipId>/clip.mp4` + `poster.jpg`;
  URL'ler tek bir edge function'dan (`clip-url`: upload/playback imzalı URL,
  kullanıcı başı günlük kota, global kesici). Byte'lar sonradan R2'ye taşınırsa
  iOS değişmez. **`coach-review-order`'ın base64 yolu kullanılmaz.**
- RLS: klibi yalnız owner + `clip_recipients` okur; oyları owner (toplu) ve
  oy sahibi (kendi) okur; `declared_rating_*` yalnız owner.
- Silme: owner siler → trigger `purge_at` koyar → mevcut purge deseni objeyi
  siler (DB cascade objeyi silmez).
- Puanlama fonksiyonu `clip_tally(clip_id)`: koç ve oyuncu sayımlarını ayrı
  döndürür; eşik altını `null` verir (ekran "henüz yok" der).

## 8. Faz 2 — keşfet (şimdiden hazırlanan, şimdi yapılmayan)

`visibility` alanı bugünden var. Açıldığında değişenler: 13+ yaş sınıfı +
Declared Age Range API; yayın öncesi onay kuyruğu (Can, ~15 dk/gün 1k MAU'da,
10k'da otomatik eleme şart); rapor/engelle/24 saatte kaldır; Faz 1'de sadece
"rapor et" + yükleyenin anında silmesi yeter.

## 9. Hukuk / mağaza — Faz 1 listesi

- Clips özelliği **16+** (öz-beyan yaş bandı); 16 altı kişi karede olmaz
  (onay metni).
- "Bu klipte ben varım, kaldırın" linki — hesapsız, `samosfi.com/k/<kod>/remove`.
- Gizlilik politikasına: klip, alıcılar, koç doğrulama belgesi, beyan edilen
  puan, saklama süresi (varsayılan 180 gün, owner istediğinde).
- DPIA (kısa) — çocukların karede olma ihtimali gerekçesiyle.
- FR/TR için "karedekilerin izni var" beyanı; yüz bulanıklaştırma Faz 1.5.
- Apple 1.2: rapor + engelle + yayınlı iletişim + EULA maddesi; feed yok →
  4+ korunur.
- DSA Art. 16/17: bildirim formu + gerekçe şablonu (mikro işletme, Section 3
  muaf).

## 10. Kendi kendine yürüyen döngü (operatörsüz) — Can, 12 Eki

> "Direkt ben olmadan iki kullanıcının birbiriyle iletişim kurabileceği
> bir mekanizma peşindeyim."

Kaptan yok, koç devşirme yok, seed grubu yok. **Her şey bir kişi + bir klip +
paylaşım sayfasından başlar** ve ikinci kişi uygulamasız değer alır.

### Döngü (A uygulamalı, B uygulamasız)
1. **A** klip seçer (PHPicker) → vuruş türü → "Bu vuruşta ne görüyorsun?"
   düğmesi → paylaşım sayfası (WhatsApp / iMessage / Stories).
   Link: `samosfi.com/k/<klipKodu>` — A'nın davet kodunu da taşır.
2. **B** linki tarayıcıda açar: klip döngüde oynar, aynı 4 soru, hesap yok,
   yükleme yok. Cevaplar → anında **"senin bakışın vs şimdiye kadar
   bakanlar"** (gizli-oy kuralı: cevaplamadan görmez). Değer burada
   verildi; yükleme istenmedi.
3. Aynı sayfada tek teklif: **"Senin vuruşuna kim baksın?"** → App Store.
   B yükleyip açınca link kodu okunur → A ile B **otomatik arkadaş**
   (kod yazma yok, davet onayı yok; A zaten linki göndermişti).
4. **A** uygulamayı açınca: "3 kişi baktı" + iki-tally kart. Bir cevapla
   bile kart oluşur — boş ekran yok.
5. B'nin ilk klibi → aynı döngü, B'nin çevresine. **K burada doğar.**

### t=0 problemi: arkadaşsız ilk kullanıcı
Araştırmanın en net uyarısı: "kimse bakmadı" = ilk çıkış. Operatörsüz
çözüm **AI bakışı**: klip yüklenir yüklenmez 🤖 sütunu dolu gelir
(vuruş türü, temas anı, 4 soruya AI'ın cevabı — "bakış" etiketiyle, doğru
iddiasıyla değil). İlk kullanıcı sıfır arkadaşla bile bir kart alır ve
paylaşacak bir şeyi olur: "AI şunu gördü, sen ne görüyorsun?" AI'ın işi
burada hakemlik değil, **yalnızlığı doldurmak**.

### Koçlar — devşirme değil, kendi gelir
Koç olan kullanıcı profilden "Koçum" der, belge yükler; onaylanana kadar
oyları oyuncu sayılır, hiçbir akış beklemez. Onay (Can) döngünün
**dışında** tek manuel iştir ve günde dakikalar sürer. Koç, öğrencilerine
kendi linkini atar — öğrenciler gelince grup kendiliğinden oluşur.

### Gruplar — yönetici yok
Herhangi bir kullanıcı "grup aç" der, link paylaşır; linkten gelen üye olur.
Ayın Vuruşu'nu (§13) grubu açan başlatır. Kulüp adı serbest metin; kulüp
markası resmi değildir, Faz 2'ye kadar öyle kalır.

### Uygulamasız cevaplayan için kötüye kullanım önlemi
Daily One'daki desen: IP + gün tuzlu hash, klip başına tek cevap; kalabalık
yüzdesi ≥3 cevapta görünür. Web cevapları `rater_kind = web` olarak ayrı
sütunda saklanır, koç/oyuncu tally'lerine karışmaz.

### Pilot = yayın
Ayrı bir pilot yok. Özellik TestFlight'a çıkar, Can kendi klibiyle döngüyü
bir kez döndürür, sonra **ölçüm konuşur**: link açılma / cevaplama /
yükleme / ilk klip oranları, kart paylaşım oranı, ilk 24 saatte bakış
alan klip yüzdesi. Kapılar §3'teki gibi; farkı, kimse kapıyı itmiyor.

### İnşa sırası (değişti)
1. **Web replay + cevap sayfası** (`samosfi.com/k/`) — döngünün kalbi, önce bu.
2. Yükleme + link üretimi + AI bakışı.
3. Otomatik arkadaşlık (link kodu) + iki-tally kart.
4. Koç başvurusu; gruplar; Ayın Vuruşu.

## 11. Can'ın cevaplaması gerekenler

1. Koç doğrulamada hangi belgeler kabul (ITF/PTR/USPTA/LTA/TTF/FFT yeterli mi,
   kulüp yazısı sayılır mı)?
2. Q2 şık listeleri: her vuruş türü için 4–6 hata — bunu **sen** yazmalısın
   (içerik, Tennis IQ'daki gibi).
3. Puan sistemi varsayılanı: WTN (İrlanda/İngiltere/Fransa) mı UTR (ABD) mı?
   İkisi de + bant mı?
4. Arkadaş tavanı 20 doğru mu?
5. Klip saklama: 180 gün mü, süresiz mi?
6. Koçlara ne vaat ediliyor (yıldız + öne çıkma yeter mi, Faz 2'de müşteri
   akışı sözü verilecek mi)?
7. AI bakışı t=0'da hangi 4 soruyu cevaplar, hangilerinde "bu açıdan göremiyorum" der?
8. Faz 1 ürün adı: "Klipler" mi, "Göz" mü, başka mı?

## 12. İş yükü (tahmin)

| Parça | Boyut |
|---|---|
| Veri modeli + RLS + `clip-url` + `clip_tally` | M |
| Yükleme akışı (PHPicker, kırpma, sıkıştırma, poster) | M |
| Cevaplama ekranı (4 soru, dokunarak an işaretleme) | M |
| Sonuç ekranı + fark göstergesi + göz puanı | M |
| Arkadaş grafı + kod/link + AASA `/f/*` `/k/*` | S–M |
| Koç doğrulama başvurusu + Can onay (panel) | S |
| Paylaşım kartı + web replay sayfası (samosfi.com) | M |
| Profil bölümleri | S |

Toplam: pilot sonrası 3–4 hafta tek geliştirici. İlk yapılacak: §10 pilot,
kod yazmadan.

## 13. Ayın Vuruşu — kulüpte toplu analiz (Can, 12 Eki; 2. düzeltmeyle)

Hedeflenen viral parça. **Yarışma değil, dayanışma:** bir ay boyunca kulübün
herkesi aynı vuruşa bakar, herkes herkese geri bildirim verir, kimse
sıralanmaz. Apple 1.2'nin "hot-or-not" yasağının yanından değil, karşı
yönünden geçer — ama bu dokümandaki korkuluklar yine şarttır.

### Mekanik
- Aylık, **tek vuruş** (Ekim: forehand, Kasım: servis…). Kulüp = §6'daki grup;
  ayı doğrulanmış koç ya da kaptan açar.
- **Katılım isteğe bağlı:** üye "bu ay katılıyorum" deyip klip atar; katılmayan
  hiçbir yerde görünmez.
- Herkes herkese bakar, aynı kriter kartıyla (5 kontrol noktası: hazırlık,
  temas, bitiriş, ayak, zamanlama; 1–5 ya da "—"). **Beğeni yok, sıra yok.**
  Her katılımcı en az 5 başkasına bakmadan kendi kartını göremez — dayanışma
  mekanik olarak zorunlu.
- Ay kapanınca her katılımcı **kendi kartını** alır: üç bakış yan yana —
  ⭐ koçlar, 👥 üyeler, 🤖 AI — ve geçen ayki kendi klibine göre değişim.
  Kart yalnız sahibine açılır.
- Kulübe açık tek şey: koçların **"bu ay bakmaya değer"** dediği 3 klip —
  örnek olarak, madalya olarak değil; sıra numarası yoktur, "en iyi" yazmaz,
  gerekçesi yazar ("temas noktası önde — buna bakın"). Sahibi isterse çıkarır.
- "En çok gelişen" yalnız kişinin kendisine söylenir, listelenmez.

### AI: üçüncü bakış, puan tablosu yok
AI kartta üçüncü sütundur; "AI'ın seçimi", "AI'ı yendi", "AI yanıldı" gibi
hiçbir ifade yoktur — çünkü ortada doğru yok. AI'ın bakışı koç ve üye
bakışından farklıysa kart bunu "üç bakış ayrıştı" diye gösterir, kimseyi
haklı çıkarmaz. (Can, 12 Eki: "AI ile insanları yarıştırırız bir noktada,
önemli değil" — yarıştırma ancak katılımcılar isterse ve yine sıralamasız.)

### Paylaşım
Katılımcı **kendi kartını** paylaşır (üç bakış + değişim, kulüp adı, ay,
grup kodu). Kulübün paylaştığı: "bu ay 23 kişi birbirinin forehand'ine
baktı, 3 örnek klip" — isim yok. Evrensel link: tarayıcıda 3 örnek klibi
izle, "sen ne görüyorsun?" → "kulübüne katıl".

### Korkuluklar (bunlar olmadan özellik yok)
- Soru her zaman vuruş hakkında, kişi hakkında değil; görünüm/beden/yaş
  için alan yok, serbest metin yok (Faz 1).
- Hiçbir ekranda sıra numarası, "en iyi/en kötü", "kazandı/yendi" yok.
- 16+; 16 altı katılamaz (junior ayı ancak kulübün izinleri tuttuğu
  koç-yönetimli kapalı grupta, Faz 2).
- Katılımcı istediği an çekilir, klibi ve kartı anında kaybolur.
- Koç yoksa koç sütunu boştur; "örnek klip" seçimi yapılmaz.
- Grup yöneticisi = doğrulanmış koç ya da kaptan; rapor/engelle geçerli.

### Faz
§6 gruplar ve §3 koç doğrulaması üstüne; grubu açan kişi başlatır, operatör
gerekmez. Açılma eşiği: grupta ≥8 üye.
