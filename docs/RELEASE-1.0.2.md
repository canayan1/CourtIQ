# DropVolley 1.0.2 (build 27) — Release paketi

**Tema:** Freemium açılış + "zahmetsiz kullanım" UX diyeti + AI grounding + doubles karşılıklı profil.
Branch: `fix/app-store-rejection-build14` (main'e FF-merge bekliyor, aşağıda).

## Bu sürümde ne var

| Alan | Değişiklik |
|---|---|
| Model | **Hard paywall → free tier.** İçerik bedava; para yakan AI (Coach + swing) premium, 1 bedava swing tadımı (`PremiumGate`). |
| Onboarding | 16 ekran/~15 karar → **9 ekran/4 tek-dokunuş soru**; kaldırılan girdiler çıkarımla dolduruluyor; evidence/paywall ısındırması kaldırıldı. |
| Showcase | Kendi kendini oynatan demo (4.2sn otomatik sayfa + kart içi sahneleme; Reduce Motion'a saygılı). |
| Aktivasyon | İlk açılışta 2 adım: 1 IQ senaryosu + anında "neden" → Coach'a yönlendirme. Bir kez gösterilir; mevcut kullanıcılar muaf. |
| Swing girişi | Forehand + sağ el ön-seçili çipler; CTA fold üstünde; film ipucu capture adımında. |
| Coach onayı | ~200 kelime → 3 ikonlu satır + "tam liste" açılırı (5.1.1(i)/5.1.2(i) içeriği aynı ekranda). |
| Sağlık onayı | Toggle kaldırıldı; tek dokunuş = açık onay (zaman damgalı kayıt aynı). |
| Maç girişi | 🎤 "İstersen konuş" — cihaz-içi transkripsiyon notlara yazar, ses dosyası silinir. Yeni izin yok. |
| Erişilebilirlik | Dynamic Type 191 sitede; ikon-buton etiketleri; VoiceOver düzeltmeleri. |
| Home | Coach hero + eşit Swing/IQ + tam-genişlik satırlar; ölü dokunma alanı düzeltildi (`contentShape`). |
| AI grounding | Doubles skoru istemcide deterministik; match sinyalleri kural-tabanlı; edge fonksiyonlarına tenis referansları + **global bütçe kesicisi** (deploy bekliyor, aşağıda). |
| İçerik derinliği | **Quiz bankası 66 → 156** (kategori başına 26, TR+EN, 77 diyagramlı) — günlük ritüel ~13 günden ~31 güne tekrarsız. |
| Practice düzeltmesi | Practice grid'inde Home'dakiyle aynı mis-routing + ölü dokunma bug'ı bulunup düzeltildi (Doubles tile Drill açıyordu). |
| Ölü dokunma kök nedeni | `BrandedPhotoBackground` scaledToFill görselleri `.clipped()` dışında hit-test alıyordu → komşu buton/satırların dokunuşlarını yutuyordu. `.allowsHitTesting(false)` ile kalıcı çözüm (Doubles davet butonları, Home, Practice). |
| Doubles: karşılıklı profil | Bağlı eşleşmelerde rapor artık **"Eşleşme" bölümü** gösteriyor: Sen \| Partner yan yana mini profil kartları (seviye, stil, güçlü yönler, gelişim alanları). Paylaşım davet + kabul ekranlarında tek satırla açıkça bildiriliyor (EN/TR). İki simülatörle E2E doğrulandı; deterministik skor iki tarafta tutarlı. |
| AI onay ekranları (4 özellik) | Swing/Maç/Mental/Doubles onayları Coach kalıbına çekildi: fayda-önce başlık + 3 dürüst satır; "Google LLC, ABD merkezli üçüncü taraf…" paragrafı yerine tek kilit satırı (Gemini adıyla) + "Tam olarak ne paylaşılıyor?" açılırı (ABD işleme + Agree'siz gönderim yok maddeleri aynı ekranda). 5.1.1(i)/5.1.2(i) özü korunur; consent sürümleri değişmedi. |
| Paywall dürüstlüğü (denetim) | Hard-paywall kalıntısı hero ("Every drill, quiz… in one membership") ve EN-only eski benefit listesi, artık ücretsiz olan içeriği premium gibi satıyordu. Yeni hero + 3 lokalize bullet yalnızca gerçek premium'u anlatıyor (AI Koç + vuruş analizi, "gerisi zaten ücretsiz" çerçevesi). |
| Mikrofon izin metni (denetim) | `NSMicrophoneUsageDescription` yalnız swing videosunu anlatıyordu; sesli maç notu da mikrofonu kullanıyor. İki kullanımı da kapsayacak şekilde genişletildi. |

## Bilinen takipler (1.0.3 adayları)
- **[RAFTA] İspanyolca lokalizasyon (es.lproj):** sahip 3 Tem 2026'da rafa kaldırdı ("İspanyolca konuşan pazar app'e para ödeyen bir pazar değil"). İstenmeden önerme. Kapsam hazır: ~824 string + quiz bankasına `*Es` alanları + `t(en,tr)` yardımcılarının 3-dil refaktörü + ASC ES metadata.
- **Doubles Bölüm B — yakın çevre eşleştirme:** kulüp havuzları → AI partner önerisi (mental + oyun stili uyumu). Soğuk başlangıç + güvenlik tasarımı gerektiriyor; spec dokümanı yayın sonrası (docs/DOUBLES-MATCHMAKING.md).
- **Günlük ipucu yüzeyi:** `TodayView` IA yenilemesinden beri hiçbir yerden çağrılmıyor — 50 kaliteli ipucu görünmez durumda ve **TR alanları yok**. 1.0.3: ipucu kartını Home'a geri çıkar + `DailyTip`'e TR ekle (+10 yeni ipucu → 60).
- **Ölü kod temizliği:** `CourtIQ/App/TodayView.swift` ve `CourtIQ/App/PracticeView.swift` orphan. Denetimde eklenenler: `Features/Community/CommunityViews.swift` (CommunityFeedView/TipCommentSectionView hiçbir yerden çağrılmıyor; içindeki "Sign in to join" butonu yanlışlıkla paywall açıyor — canlıya çıkmadan düzeltilmeli ya da silinmeli) + kullanılmayan `paywall.tip_*` string'leri (terk edilmiş tip-jar tasarımı).
- **UI test bakımı:** `-previewPaywall` artık kök paywall render etmiyor (freemium) — `AppStoreScreenshotUITest` paywall karesi Coach sekmesi üzerinden alınmalı.
- Tekrar-oynanabilirlik mekaniği: hata desenlerinden "review session" + haftalık IQ seviyesi.

## App Store Connect — kopyala-yapıştır

**What's New (TR):**
> DropVolley artık ücretsiz başlıyor! • Yepyeni, 1 dakikalık hızlı kurulum • Maçını sesle kaydet — konuş, biz yazalım • Doubles: partnerinle eşleşince raporda artık iki oyuncunun profili yan yana • Daha akıcı Swing Analizi başlangıcı • Yazı boyutu artık her yerde erişilebilirlik ayarınla ölçekleniyor • Hata düzeltmeleri ve genel cilalar

**What's New (EN):**
> DropVolley now starts free! • All-new 1-minute setup • Log matches by voice — just talk, we'll write it down • Doubles: pair up and see both players' profiles side by side in your report • Smoother Swing Analysis start • Text now scales with your accessibility settings • Bug fixes and polish

**Promotional Text (EN, 170 kr.):**
> Most tennis apps track your score. DropVolley makes you smarter on court — AI coach, swing scores, match insights. Free to start.

**Promotional Text (TR):**
> Skoru herkes tutar; DropVolley seni kortta daha zeki yapar — AI koç, vuruş puanı, maç analizi. Ücretsiz başla.

**Açıklama ilk paragraf önerisi (freemium vurgusu):**
> EN: "DropVolley is your Tennis IQ coach — and it's free to start. Sharpen your decisions with scenario quizzes, log matches (by voice!), get AI insights, and when you're ready, unlock the AI Coach and 0–100 swing analysis."
> TR: "DropVolley senin Tennis IQ koçun — ve başlaması ücretsiz. Senaryo quizleriyle karar zekânı geliştir, maçlarını (sesle!) kaydet, AI içgörüleri al; hazır olduğunda AI Koç'u ve 0–100 vuruş analizini aç."

## Gönderim kontrol listesi

1. ☐ **Edge deploy (Claude, açık onayla):**
   `yes | supabase db push` → `supabase functions deploy match-analysis doubles-analysis swing-analysis --use-api` → smoke.
   *Neden şart:* istemci 1.0.2 doubles skorunu kendisi hesaplayıp gönderiyor; canlı fonksiyon deploy edilmezse metindeki skor ile ekrandaki skor çelişebilir. Kesici de bu pakette.
2. ☐ **Main'e merge + push (Claude, açık onayla):** `git checkout main && git merge --ff-only fix/app-store-rejection-build14 && git push origin main` (FF garantili: 150 önde / 0 geride).
3. ☑ Archive: `DropVolley-1.0.2-27.xcarchive` (3 Tem 2026 — doubles karşılıklı profil + hit-testing kök neden düzeltmesi dahil; eski tarihli arşivleri KULLANMA) → Xcode Organizer'da.
4. ☐ **Upload (insan):** Xcode → Organizer → Distribute App → App Store Connect (Apple ID/2FA gerektiği için Can).
5. ☐ ASC: What's New yapıştır (yukarıda), fiyat/IAP değişmedi, gönder.
6. ☐ Gönderim sonrası: `git tag v1.0.2 && git push origin v1.0.2`.
