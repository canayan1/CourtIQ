# DropVolley — Ürün Tutarlılık Denetimi + Repositioning
**13 Tem 2026 · Kanıt-temelli (ölçüldü, iddia değil) · Karar: Can**

Bağlam: "birçok feature satıyoruz ama hiçbiri tam çalışmıyor sanki; app kullanıcısını
bulamıyor." Doğru teşhis. Sorun **isim/tema değil, odak.** Aşağıdaki kanıt bunu somutluyor
ve tek bir wedge işaret ediyor.

---

## 1. KANIT — neyin gerçek olduğu

### 🟢 Tennis IQ — GERÇEK VE SAĞLAM (mock/lint ile doğrulandı)
`quiz_questions.json`, 156 senaryo:
- **6 kategori tam dengeli:** serve · return · rally · net · mental · doubles = **26'şar**
- **Tam çift dil:** 0 eksik/tutarsız TR çeviri
- **0 geçersiz doğru-cevap indeksi · 0 eksik açıklama · 0 tekrar eden soru**
- **%81 diyagramlı** (127/156) · hepsi `mistakeType` etiketli (müfredat köprüsü)
- Zorluk eğrisi mantıklı: easy 58 / medium 75 / hard 23
- **İçerik-tabanlı → AI belirsizliği YOK.** Deterministik doğru cevap, ucuz, demolanabilir,
  rakiplerde yok.
→ **Appin bulamadığı kimlik bu. Zaten elimizde, sadece az satıyoruz.**

### 🟢 AI Coach — ÇALIŞIYOR (en iyi AI özelliği)
- Canlı testte gerçek, kişiselleştirilmiş cevap (maç verisine atıf: "servisin 2/5'e düştü").
  Manuel + profile dayalı, genel chatbot değil.
- ⚠️ Tutarlılığı henüz golden-suite ile ölçülmedi (bench + Gemini anahtarı gerekiyor).

### 🟠 Doubles skoru — AŞIRI VAAT (deterministik ama yanıltıcı)
`DoublesCompatibility.evaluate` — 1250 kombinasyonluk mock matris:
- **Deterministik ✓** (aynı girdi → aynı çıktı, uydurma yok) · **yön doğru ✓** (mükemmel 91, kötü 51)
- **AMA gerçek aralık yalnızca 51–91.** `[40,96]` clamp'i ölü kod. "100 üzerinden" diyoruz
  ama 51 altı / 91 üstü **imkânsız**.
- **Profilsiz kullanıcı HER partnerde 68 veya 71 alıyor** — sabit, partnerden bağımsız.
  (Partner mini-profili boş bırakılırsa da 68/71.) Optional bir profile bağlı → büyük kitle.
- Tam-profil dağılımı: **%74'ü 70+, %33'ü 80+** → "herkes harika uyumlu" → sayı anlamını yitiriyor.
- En kötü olası eşleşme (4 seviye fark + aynı gereksiz stil) bile **51** = "ortalama altı" —
  kullanıcıya asla dürüstçe "bu zayıf bir eşleşme" diyemiyoruz.
→ Kocaman **"87 / 100"** halkası aslında 51-91 arası bir ruh-hali göstergesi. Kırık değil,
  **dürüst değil.** (Tam da "feature var ama tam çalışmıyor" hissinin kaynağı.)

### 🔴 Swing analizi — GÜVENİLİR DEĞİL
- Bütün bir oturum kanıtladı: video-LLM hareketi göremiyor. Gerçek çözüm = on-device pose +
  Create ML (Faz 2-3, haftalar). Bugün Faz 1 kalkanları var ama **hero olamaz.**

### 🟠 Duvar — YARIM
- İçerik + pacer çalışıyor; heyecanlı kısmı (Rally Cam) 1.0.3'te çekildi → eksik hissediyor.

---

## 2. REPOSITIONING TEZİ — tek wedge

> **DropVolley: tenisi *düşünmeyi* öğreten uygulama.**
> (İsim zaten söylüyor — *Tennis IQ Coach*. Değiştirme.)

**Çekirdek döngü (günlük ~60 sn, %100 çalışıyor, ucuz, özgün):**
Günün senaryosu → kararı ver → *neden*'i öğren → streak → yarın devam.

**Kimlik hiyerarşisi (kırpma değil, sıralama):**
- 🥇 **KAHRAMAN — Tennis IQ:** günlük senaryo + 6 kategori yolu + müfredat + diyagramlar
- 🥈 **DESTEK-1 — AI Coach:** IQ'yu kişiselleştirir ("senin oyununu bilen koç")
- 🥉 **DESTEK-2 — hepsi "IQ" şemsiyesinde:** Doubles IQ · Duvarda IQ drilleri · Mental check
- 🅱️ **BETA/RAF — Swing:** pose pipeline bitene kadar dürüst "beta", hero değil

Bu, mevcut App Store konumlandırmasının (IQ-lead) zaten yarısı. Fark: **"her şeyi yapıyoruz"
tonunu bırak, "biz IQ appiyiz, gerisi onu besler" tonuna geç.** Kullanıcı ne olduğunu 3 saniyede
anlasın.

**İsim/tema:** İkisi de KALIR. İsim wedge'i zaten söylüyor + ASO/marka sıfırlaması elde ne
varsa siler. Clay/cream özgün, sorun değil. Enerjiyi buraya harcamak koltuk dizmektir.

---

## 3. FEATURE KARARLARI

| Feature | Karar | Aksiyon |
|---|---|---|
| **Tennis IQ** | 🥇 Kahraman | Home hero + günlük ritüel + kategori yolları + streak vurgusu |
| **AI Coach** | 🥈 Destek | IQ'ya bağla; golden-suite ile tutarlılık ölç |
| **Doubles** | 🔧 Onar + dürüstle | §4 (skoru dürüst hale getir) |
| **Duvar** | Bağla | "Duvarda IQ drilleri"; Rally Cam premium yol haritası (Duolingo vizyonu) |
| **Mental check** | Destek | Maç öncesi rutin — kalır |
| **Swing** | 🅱️ Beta/raf | Hero'dan indir; dürüst "beta" rozet; pose pipeline'a kadar öne çıkarma |
| **Match log** | Altyapı | Coach'u besler; sessiz kalır |
| **Beginner path** | Büyütücü | "Sıfırdan Kortta" IQ kimliğini genişletir (tasarlandı, docs/LEARN-TENNIS-DESIGN.md) |

---

## 4. DOUBLES SKORU — somut düzeltme (üç seçenek, en dürüstü önerilir)

1. **Profil yoksa sayı YOK.** Sabit-68'i "uyum skoru" diye sunma. Yerine: "Profilini
   tamamla → uyum skorunu aç" CTA. (En düşük eforlu, hemen dürüst.)
2. **Aralığı ger.** Taban ve ağırlıkları yeniden ölçekle: zayıf eşleşme gerçekten düşük
   (30-40'lar) görünsün, aralık 100'ü kullansın. (Sayıyı korur ama kalibrasyon işi.)
3. **Sayıyı bırak, tier + kart göster (ÖNERİLEN).** "İyi / Harika / Zorlayıcı eşleşme"
   + "3 güçlü yön · 1 dikkat noktası". Az vaat, çok teslim. Sahte hassasiyet yok →
   swing'deki "ölç, uydurma" ilkesiyle birebir tutarlı.

→ 1.0.3 zaten yüklendi; bu düzeltme **1.0.4 fast-follow** (submission blocker değil ama
  güven/tutarlılık için öncelikli).

---

## 5. GÜVENİLİRLİK DİSİPLİNİ — swing golden-suite'ini her yere

- **Doubles:** bu mock matris testi CI'a → assert'ler: profilsizde sayı yok · aralık gerçekten
  geniş · en-kötü < eşik. (`tools/` altında `doubles-goldens`.)
- **Coach:** bench + golden vakalar (Gemini anahtarı gelince) — tutarlılık + halüsinasyon taraması.
- **Tennis IQ:** içerik lint (indeks/çeviri/tekrar/kategori dengesi) — bugün 0 hata, cron'la koru.
- Kural (swing'den): **golden yeşil değilse deploy yok.** Her feature'a genişlet.

---

## 6. SIRA (repositioning yürütme)
1. Doubles skorunu dürüstleştir (§4.3 önerilen) — kod, 1.0.4
2. Home/Train tonunu IQ-lead yap — kopya + hiyerarşi (kırpma yok)
3. Swing'i "beta" rozetine indir, hero'dan çıkar
4. Coach golden-suite (anahtar gelince)
5. Beginner "Sıfırdan Kortta" yolu → IQ kimliğini büyüt

## Özet
App bozuk değil — **odaksız.** Elimizde gerçek, özgün, çalışan bir çekirdek var (Tennis IQ +
Coach). Kanıt: IQ kusursuz (156 senaryo, 0 hata), Coach çalışıyor, Doubles aşırı-vaat ama
düzeltilebilir, Swing haftalar-uzağında. Yön: **IQ'yu kimlik yap, gerisini ona bağla, sahte
hassasiyeti (doubles skoru) dürüstle, güvenilirliği golden-suite ile kilitle.** İsim/tema kalır.
