#!/usr/bin/env python3
"""doubles-bench — DoublesCompatibility.evaluate deterministik skorunun mock-matris
stres testi (docs/PRODUCT-COHERENCE.md §1). Swift mantığının birebir portu; kaynak
değişince buradaki katsayıları senkron tut. Çıkış kodu ≠ 0 = güven assert'i düştü."""
import itertools, statistics, sys
LEVELS=range(5); ARCH=["developing","aggressiveBaseliner","counterpuncher","allCourt","serveVolleyer"]
def fit(a,b):
    if "developing" in (a,b): return 0
    if "allCourt" in (a,b): return 7
    return -3 if a==b else 10
def score(ul,ua,pl,pa,lefty):
    s=68
    if ul is not None and pl is not None: s+={0:10,1:6,2:0,3:-8}.get(abs(ul-pl),-14)
    if ua is not None and pa is not None: s+=fit(ua,pa)
    if lefty: s+=3
    return max(40,min(96,s))
full=[score(*c) for c in itertools.product(LEVELS,ARCH,LEVELS,ARCH,[False,True])]
noprof={score(None,None,pl,pa,lf) for pl,pa,lf in itertools.product(LEVELS,ARCH,[False,True])}
print(f"tam-profil: min={min(full)} max={max(full)} ort={statistics.mean(full):.1f} n={len(full)}")
print(f"profilsiz olası skorlar: {sorted(noprof)}")
# GÜVEN ASSERT'LERİ (repositioning sonrası bunlar YEŞİL olmalı; bugün kasıtlı KIRMIZI)
fails=[]
if min(full)>45: fails.append(f"zayıf eşleşme çok yüksek (min={min(full)}, <46 bekleniyor)")
if len(noprof)>1 or 68 in noprof: fails.append(f"profilsiz sabit-skor sunuluyor ({sorted(noprof)}) — sayı gösterilmemeli")
if sum(s>=70 for s in full)/len(full)>0.5: fails.append("skorların >%50'si 70+ (herkes 'harika uyum')")
print("\nGÜVEN ASSERT'LERİ:", "YEŞİL ✅" if not fails else "KIRMIZI ⛔ (repositioning gerekiyor)")
for f in fails: print("  ✗", f)
sys.exit(1 if fails else 0)
