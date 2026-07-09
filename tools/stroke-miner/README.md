# stroke-miner — arşiv videosundan eğitim verisi + Create ML eğitimi (Faz 3)

Uzun tenis videolarını ses-impact tespitiyle 2.2 sn'lik etiketli kliplere böler
(`mine.py`), sonra Create ML Action Classifier ile cihaz-içi vuruş sınıflandırıcısını
eğitir (`train.swift`). Plan: docs/SWING-PIPELINE-PLAN.md · Tamamı lokal, $0.

## Madencilik

```bash
python3 mine.py --video ~/TennisVideos/instagram/forehand_wall_9929.mov \
                --label forehand --out ~/TennisVideos/_training/v0 [--dry-run] [--no-other]
```

- Tespit: yüksek-geçiren farklayıcı → 10 ms RMS zarfı → adaptif eşik (medyan+6·MAD)
  → 1.4 sn min-aralıklı tepe seçimi (aralıkta en güçlü kazanır → mikrofona yakın
  RAKET vuruşu, uzak duvar sekmesini eler).
- Kesim: temas −1.3 s … +0.9 s (66 kare @30fps), h264, sessiz, dikey korunur.
- `--dry-run` önce zamanları gösterir; `--no-other` sessiz-aralık negatiflerini atlar.

## Eğitim

```bash
xcrun swiftc -O train.swift -o stroketrain
./stroketrain ~/TennisVideos/_training/v0 ~/TennisVideos/_training/v0/DropVolleyStroke_v0.mlmodel
```

Pencere 60 kare @30fps (kliplerle uyumlu), otomatik doğrulama bölmesi, eğitim/doğrulama
doğruluğu + karışıklık matrisi basar, `.mlmodel` yazar.

## Etiket kontrol (tek-tuş yeniden etiketleme)

```bash
python3 labelcheck.py ~/TennisVideos/_training/v0   # labelcheck.html üretir
open ~/TennisVideos/_training/v0/labelcheck.html    # dokun→oynat; yanlışsa doğru etikete bas
# "relabels.json indir" → sonra:
python3 apply_labels.py ~/TennisVideos/_training/v0 ~/Downloads/relabels.json
```

Poster = temas anı karesi (1.3 sn). tweener/çöp `_rejected/` altına taşınır, eğitime girmez.

## Ground-truth kalibrasyonu (Can'ın elle sayımı, 9 Tem)

| Video | Gerçek | Ses tespiti | Poz-kapı sonrası |
|---|---|---|---|
| 9929 | 19 FH + 5 BH (2 FH kadraj dışı) | 31 | 19 |
| 9931 | 32 BH + 2 FH (birkaçı kadraj dışı) | 42 | 29 |
| 9932 | 28 BH + 3 bacak-arası + 1 FH | 41 | 33 |
| 9933 | 20 smaç | 29 | 24 |

→ Ham ses sayımı %20-45 FAZLA sayar (duvar sekmesi/çevre sesi); insan-görünür kapısıyla
gerçeğe yaklaşır. **Faz 1'in app-içi sayacı ses + Vision insan-kapısı BİRLİKTE olmalı.**
Ayrıca bilinen etiket gürültüsü: FH klasöründe ~5 BH, BH'de 2-3 FH + 3 bacak-arası,
smaçta ~4 fazla → labelcheck ile temizlenip v0.2 eğitilecek.

## v0 dürüstlük notları

- **Tek denek (Can), tek mekân, arka açı, duvar bağlamı** → v0 bir PROTOTİP;
  genel doğruluk iddiası için farklı oyuncular şart (Faz 3 kapısı).
- Sınıf dengesi çarpık olabilir (BH ≈ 2× FH) — v1'de flip-augmentasyon + ek çekim.
- "other" (vuruş yok) sınıfı v0'da yok: dağıtım sözleşmesi, yalnızca impact-merkezli
  pencerelerin sınıflanması (ses tespiti kapıyı tutar).
