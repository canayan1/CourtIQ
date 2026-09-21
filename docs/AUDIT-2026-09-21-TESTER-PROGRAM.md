# DropVolley — durum denetimi, 21 Eylül 2026

Amaç: Instagram'dan 10 kişiye "1 ay ücretsiz" verip test yaptırmadan önce,
mağazadaki uygulamanın, abonelik altyapısının ve arka ucun *bugünkü* hali.
Her satır bu sabah ASC API'sinden, koddan ya da canlı URL'lerden okundu;
tahmin olan yerler "kaba" diye işaretli.

## 1. Mağaza

| | |
|---|---|
| Canlı sürüm | **1.3 (build 38)**, `READY_FOR_SALE`, 16 Eyl. Kod: `e53760d`. |
| Bekleyen | **1.4 (build 39)**, `WAITING_FOR_REVIEW`, 20 Eyl, manuel yayın. İçerik: Daily IQ'dan meydan okuma linki + paylaşım linki düzeltmesi. |
| Bölge | Tüm bölgeler açık, yeni bölgelere otomatik. |
| Yorumlar | 2 yorum, ikisi 5★ (TUR, ESP; 2 Tem). |
| Fiyat | Yıllık €69.99 (IE) / $59.99 (US) / ₺2.999,99; haftalık €9.99 / $9.99 / ₺499,99. Yıllıkta 3 günlük giriş denemesi var, haftalıkta yok. |
| URL'ler | privacy / terms / support / marketing / AASA hepsi 200. Uygulama-bilgisi gizlilik URL'si hâlâ `canayan-ios-apps.vercel.app` (çalışıyor; kanonik adres `samosfi.com` — kozmetik). |
| Liste metni | Doğrulandı: "3-day free trial", "$59.99/year", "Built in Ireland", "shaped by certified coaches", "waitlist inside the app" — hepsi koda/ASC'ye uyuyor. |

## 2. Testerin göreceği ürün (1.3)

Ücretsiz: Tennis IQ (156 senaryo), Tactics 1. bölüm + günde 1 ders, duvar
merdiveni, Journal (maç + beslenme + kaynaklı rehber), doubles uyumu, mobility.
Premium: AI Coach, tam swing analizi (1 ücretsiz tadım), kamerayla puanlanan
duvar, tüm Tactics dersleri, tam geçmiş, 12 tarif.

Mağaza build'inde OLMAYAN (main'de DEBUG arkasında): bel-telefonu/Watch
seansı, bench kartı, trendler, Practice/Teaching. İyi — hiç çalıştırılmadı.

## 3. "1 ay ücretsiz" nasıl verilir — hazır olan

Abonelik teklif kodları ASC'de zaten var:

| kod grubu | ürün | süre | uygunluk | stok | son tarih |
|---|---|---|---|---|---|
| **1 Month Free** — tek-kullanımlık | Yıllık | 1 ay ücretsiz | yeni + mevcut + süresi dolmuş; giriş denemesine **eklenir** | 1000 (2 Tem'de üretildi; kaçının dağıtıldığı bilinmiyor) | 31 Ara 2026 |
| `LANSDOWNE` — özel kod | Yıllık | 1 ay | herkes | 500 | **30 Eyl 2026** (9 gün) |
| `LANSDOWNE30` — özel kod | Yıllık | 1 ay, giriş denemesinin yerine | herkes | 500 | 30 Kas 2026 |
| `lansdowne30` — özel kod | Haftalık | 1 ay | yalnız yeni | 1000 | — |
| 1 Year Free | Yıllık | 1 yıl | herkes | 1000 | — |

Kullanım linki (uygulama gerekmez, App Store açar):
`https://apps.apple.com/redeem?ctx=offercodes&id=6773753464&code=<KOD>`

Uygulama tarafı: açılışta `Transaction.currentEntitlements`, arka planda
`Transaction.updates` dinleniyor; kod kullanıldıktan sonra uygulama açılınca
premium gelir, gelmezse paywall'daki "Restore Purchases" var. Uygulamada
"kod gir" düğmesi (`presentOfferCodeRedeemSheet`) **yok** — link yeterli,
1.5'e iki satırla eklenir.

**Karar önerisi:** 10 kişi için `1 Month Free` grubunda **yeni bir tek-
kullanımlık parti** (15 kod, 60 gün geçerli) üret; eski 1000'lik partiden
kod verme — hangileri kullanıldı bilinmiyor, bir tester "kod geçersiz"
görürse ilk izlenim o olur. Özel kod (`LANSDOWNE30`) verme: Instagram'da
bir kişi paylaşırsa 500 kişi kullanır.

**Testerlara mutlaka söylenecek:** kod yıllık aboneliği başlatır; ~33 gün
sonra (3 gün deneme + 1 ay) **€69.99 yıllık olarak yenilenir**. Apple
deneme bitmeden hatırlatma e-postası gönderir ama "istemiyorsan bitmeden
iptal et" cümlesi mesajda olmalı. Ödeme korkusu istemiyorsan alternatif
haftalık `lansdowne30`: yenilenirse €9.99, ama yalnız hiç abone olmamışlara.

**Yapılmayacak:** ücretsiz ayı App Store puanına/yorumuna bağlama, "5 yıldız
verirseniz" deme. Geri bildirim iste, puan isteme (mağaza kuralı + dürüstlük
kuralımız).

## 4. Maliyet ve korumalar (10 tester için)

| | kullanıcı başı | küresel |
|---|---|---|
| AI Coach | 50 mesaj/gün | 1500 çağrı/gün kesici |
| Swing analizi (Gemini video) | 3/gün, 30/ay | aynı kesici |
| Doubles / maç analizi | — | aynı kesici |

Arka uçta RevenueCat yetki kapısı `REQUIRE_ENTITLEMENT=false` (karanlık,
açık-hata): yetki yalnız uygulama tarafında kontrol ediliyor. 10 tester için
sorun değil; kalabalık dağıtımdan önce açılmalı.
Kaba maliyet: 10 kişi tavanı zorlasa bile AI Coach günde <€1, swing günde
<€6; gerçekçi kullanım bunun onda biri.

## 5. Testerların çarpacağı bilinen kusurlar

1. **Paylaşım linki 1.3'te ölü.** Quiz/drill sonucunu paylaşınca metinde
   `courtiq.app` var — bize ait olmayan alan adı. 1.4'te düzeltildi,
   incelemede. **Kodları 1.4 yayına girdikten sonra dağıt**; olmazsa
   testerlara "paylaş düğmesine basmayın" deme, sadece bil.
2. **Swing analizi en zayıf premium özellik** ve ana ekranın ilk kartı.
   1.3'te hâlâ Gemini Flash video sınıflandırması (`gemini-2.5-flash`,
   ses sayımı + model). Araştırma VLM'lerin hareket-kör olduğunu gösterdi;
   deterministik hat henüz mağazada değil. En sert geri bildirim buradan
   gelecek — bu iyi, ama sürpriz olmasın.
3. **Gerçek koç incelemesi** "coming, waitlist inside": IAP satıştan
   çekildi, bekleme listesi görünüyor. Kimse ödeme yapamaz; doğru.
4. Uzaktan çökme görünürlüğü yok: MetricKit raporları cihazda kalıyor.
   Bir tester "çöktü" derse ekran görüntüsü + ne yaptığı tek kaynak.

## 6. Geri bildirim toplama — eksik olan

- Uygulamada geri bildirim düğmesi yok; destek URL'si sadece Legal
  ekranında. Testerlar için bir **WhatsApp/IG grubu + 5 soruluk form**
  (ilk 5 dakikada ne yaptın / ne anlamadın / ne için para verirdin / hangi
  ekranda çıktın / cihaz-iOS) kur. Uygulama içi düğme 1.5'e.
- Firebase Analytics bağlı (`GoogleService-Info.plist` var), 1.4'te ekran
  takibi genişledi. **App Privacy etiketlerinde "Analytics / Usage Data"
  beyanı 1.4'ten önce web UI'da kontrol edilmeli** (senin işin).
- TestFlight'ta hiç grup yok. TestFlight ile "1 ay" vermek yanlış araç:
  sandbox abonelikleri hızlandırılmış yenilenir (yıllık = 1 saat, 6 kez)
  ve sonra düşer. Kodlar mağaza build'inde; TestFlight yalnız 1.4'ü onay
  öncesi göstermek için.

## 7. Dağıtımdan önce sıra

1. 1.4 onayı → manuel yayın (paylaşım linki düzelsin).
2. App Privacy etiketleri (Analytics) — web UI.
3. ~~Yeni tek-kullanımlık kod partisi~~ **ÜRETİLDİ** 21 Eyl: parti
   `594833`, "1 Month Free" (yıllık), 500 kod (API'nin kabul ettiği en
   küçük parti), son kullanım 20 Kas 2026. Kodlar depoda DEĞİL — CSV ve
   ilk 15'lik liste Can'a dosya olarak verildi.
4. Tester mesajı: link + "yıllık başlar, 33 gün sonra €69.99, iptal
   bitmeden" + geri bildirim kanalı + puan istenmiyor.
5. 1.5 küçük paket: uygulama içi kod girme + geri bildirim düğmesi +
   privacy URL'sini samosfi'ye çevir.
