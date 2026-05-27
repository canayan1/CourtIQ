# CourtIQ v1.0 — App Store Submission Handoff

Hazırlanan tüm asset'ler + sana kalan adımlar. Tahmini toplam süre: **45-60 dakika**.

---

## ✅ Hazır olanlar

| İş | Durum | Konum |
|---|---|---|
| App description (EN + TR) | ✅ | `docs/APP_STORE_METADATA.md` |
| Promo text | ✅ | `docs/APP_STORE_METADATA.md` (170 char) |
| Keywords | ✅ | `docs/APP_STORE_METADATA.md` |
| What's New v1.0 | ✅ | `docs/APP_STORE_METADATA.md` |
| App icon (tüm boyutlar + marketing 1024) | ✅ | `CourtIQ/Assets.xcassets/AppIcon.appiconset/` |
| Privacy Policy URL | ✅ live | https://canayan1.github.io/CourtIQ/PRIVACY_POLICY |
| Support URL | ✅ live | https://canayan1.github.io/CourtIQ/SUPPORT |
| Terms URL | ✅ live | https://canayan1.github.io/CourtIQ/TERMS_OF_USE |
| Age rating answers | ✅ | `docs/APP_STORE_METADATA.md` (4+) |
| Privacy questionnaire answers | ✅ | `docs/APP_STORE_METADATA.md` |
| Build (.xcarchive) | ✅ | `/tmp/CourtIQ-Archive/CourtIQ.xcarchive` |
| Screenshots (2 of 6) | 🟡 partial | `marketing/screenshots/iphone-6.9/` |

---

## 🔴 Sana kalan — 3 iş

### 1) Eksik screenshot'ları çek (10 dk)

Agent **Today + launch** screenshot'ı aldı, ama bottom-tab navigation için Simulator'a tap event'i göndermek macOS Accessibility izni gerektiriyor (agent veremiyor). 4 screenshot daha lazım. **Simulator açık ve hazır** — sen sadece tap'le, ben şu komutla anında alırım:

**iPhone 17 Pro Max simulator UUID:** `F697B6CB-C71B-4D15-B00B-4EF50B59C7A2`

Sırasıyla:

```bash
# Practice tab → tap "Daily Drill" Start → mid-drill ekranı
xcrun simctl io F697B6CB-C71B-4D15-B00B-4EF50B59C7A2 screenshot \
  /Users/can/Projects/CourtIQ/marketing/screenshots/iphone-6.9/03-drill.png

# Pro Shot card → animation ortası
xcrun simctl io F697B6CB-C71B-4D15-B00B-4EF50B59C7A2 screenshot \
  /Users/can/Projects/CourtIQ/marketing/screenshots/iphone-6.9/04-proshot.png

# Matches tab → 1 maç entry (ya da boş state)
xcrun simctl io F697B6CB-C71B-4D15-B00B-4EF50B59C7A2 screenshot \
  /Users/can/Projects/CourtIQ/marketing/screenshots/iphone-6.9/05-matches.png

# Training tab → PHEC plan card
xcrun simctl io F697B6CB-C71B-4D15-B00B-4EF50B59C7A2 screenshot \
  /Users/can/Projects/CourtIQ/marketing/screenshots/iphone-6.9/06-training.png

# Profile tab → Tactical Profile card (drill yaptıktan sonra dolu)
xcrun simctl io F697B6CB-C71B-4D15-B00B-4EF50B59C7A2 screenshot \
  /Users/can/Projects/CourtIQ/marketing/screenshots/iphone-6.9/07-profile.png
```

**Tap akışı (Simulator window'unda):**
1. Bottom tab **Practice** → bul **Daily Drill** card → **Start** → ilk soru çıkınca screenshot komutu çalıştır (03-drill.png)
2. Today tab'a dön → **Pro Shot** card'a tıkla → **Play** → animasyon ortasında screenshot (04-proshot.png)
3. Bottom tab **Matches** → screenshot (05-matches.png)
4. Bottom tab **Training** → screenshot (06-training.png)
5. Bottom tab **Profile** → screenshot (07-profile.png)

### 2) Build'i App Store Connect'e yükle (15 dk)

CLI export başarısız oldu — iOS Distribution sertifikası yok. **Xcode Organizer** kendisi sertifikayı oluşturur:

1. **Xcode** aç → **Window menu** → **Organizer**
2. Sol panel → **Archives** sekmesi
3. Listede **CourtIQ (1.0 / 4)** görünmeli — yoksa şu komutu çalıştır:
   ```bash
   open /tmp/CourtIQ-Archive/CourtIQ.xcarchive
   ```
4. Archive seç → sağ üstte **"Distribute App"** mavi butonu
5. **App Store Connect** seç → **Next**
6. **Upload** seç → **Next**
7. **Automatically manage signing** ✓ → **Next** (Xcode "iOS Distribution" sertifikasını + provisioning profile'ı otomatik oluşturur)
8. Summary → **Upload**
9. ~5 dakika upload, sonra "Upload Successful" görünür

Build sonrası ASC tarafında "Processing" 30-60 dk sürer (Apple ITMS validate ediyor). Sonra TestFlight'ta görünür.

### 3) App Store Connect listing'i doldur + submit (20 dk)

App Store Connect → My Apps → **CourtIQ** (henüz yoksa **+** ile yeni app oluştur, bundle ID: `com.canayan93.courtiq`).

**Per-section copy-paste guide:**

#### Version 1.0 → **App Information**

| Field | Değer |
|---|---|
| Name | `CourtIQ` |
| Subtitle | `Train your tennis mind` |
| Privacy Policy URL | `https://canayan1.github.io/CourtIQ/PRIVACY_POLICY` |
| Category Primary | `Sports` |
| Category Secondary | `Health & Fitness` |

#### Version 1.0 → **Pricing and Availability**
- Price: **Free**
- Availability: **All countries** (175)

#### Version 1.0 → **App Privacy** (data collection survey)
`docs/APP_STORE_METADATA.md` → "App Privacy" bölümüne göre doldur:
- Track? **No**
- Linked: Email, Name, User ID, Purchase History, Product Interaction
- Not linked: Crash Data, Performance Data

#### Version 1.0 → **iOS App** (versiyon listesi)
- Click **+** → **iOS App** → **1.0**

**Promotional Text:**
```
Daily court-tap drills, pro shot patterns, match journal, and mobility — built for tennis players who think about every point.
```

**Description** — `docs/APP_STORE_METADATA.md` → "Description (English)" bloğunu komple paste.

**Keywords:**
```
tennis,drill,quiz,training,mobility,coach,match,journal,strategy,decision,pro,iq,tactics,reading
```

**Support URL:**
```
https://canayan1.github.io/CourtIQ/SUPPORT
```

**Marketing URL:**
```
https://canayan1.github.io/CourtIQ/
```

**Screenshots** → 6.9" iPhone tab → 6 PNG'yi sürükle bırak:
- `marketing/screenshots/iphone-6.9/01-launch.png` (opsiyonel — onboarding hero)
- `02-today.png` → `07-profile.png` (sıralı)

**App Review Information:**
- First name: `Can`
- Last name: `Ayan`
- Phone: telefonun
- Email: `canayan93@gmail.com`
- **Notes:**
  ```
  CourtIQ is a tennis IQ training app with daily tactical drills, pro shot animations, match journaling, and mobility flows. It uses anonymous Supabase auth (no sign-in required). The "AI Coach" feature in Profile is gated behind a Premium entitlement; please use the included test entitlement instructions to test.

  Demo: No login required — onboarding takes ~30s, then full app is accessible.
  Test entitlement: Profile → AI Coach → if locked, the paywall sheet shows tip-jar IAPs (currently inactive pending Paid Apps Agreement). Free preview of all other features works without subscription.

  Backend: Supabase Edge Function (ai-chat) handles AI Coach. Anonymous JWT auth.
  ```

**Localization** — TR ekle: dropdown → **Turkish** → Description: `docs/APP_STORE_METADATA.md` → "Description (Turkish)" bloğunu paste.

**Build** → tab'a tıkla → upload edilen build'i seç (Processing tamamlandıysa görünür).

#### Version 1.0 → **Age Rating**
`docs/APP_STORE_METADATA.md` → "Age Rating" cevaplarını işaretle:
- Tüm violence/sexual/profanity: **None**
- Medical/Treatment: **Infrequent/Mild**
- User-generated content: **Infrequent/Mild**
- Sonuç: **4+**

#### Save → **Submit for Review**

⚠️ **Önemli:** W-8BEN sorunu (Apple Support cevabı) halledilmemişse bile **submit edebilirsin**. Apple review (~24-48 saat) paralel ilerler. Paid Apps Agreement açılınca IAP'ler otomatik aktive olur, app review'u beklemez.

---

## Teknik notlar

- **Pro Shot fix:** bu sabah commit edildi, archive bu fix'i içeriyor (commit `be12d31`)
- **Build version:** 1.0 (4) — Info.plist'te
- **Bundle ID:** `com.canayan93.courtiq`
- **Team ID:** `DC8ALPY949`
- **Code signing:** Automatic (Xcode Organizer halleder)

## Sonra (post-submission)

- TestFlight beta: aynı build'i internal test grubuna assign et, telefonlardan test
- Apple Support'tan W-8BEN cevabı gelince → form'u submit et → Paid Apps Agreement aktive olur → tip jar IAP'leri canlanır
- Marketing URL: courtiq.app domaini alındığında ASC'ten tek satır güncelleme

---

**Çıkış noktası:** Bu doc + `docs/APP_STORE_METADATA.md` ikisini açık tut, sırasıyla copy-paste et. 1 saat içinde "Waiting for Review" durumunda olursun.
