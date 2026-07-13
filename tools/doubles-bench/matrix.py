#!/usr/bin/env python3
"""doubles-bench — DoublesCompatibility.evaluate DÜRÜST tier mantığının mock-matris
testi (docs/PRODUCT-COHERENCE.md). Swift portu; kaynak değişince senkron tut.
Eski sürüm 0-100 skoru test ediyordu (aşırı-vaat kanıtı); bu sürüm tier + profilsiz
davranışı test eder. Çıkış kodu ≠ 0 = güven assert'i düştü."""
import itertools, collections, sys
LEVELS=range(5); ARCH=["developing","aggressiveBaseliner","counterpuncher","allCourt","serveVolleyer"]
def fit(a,b):
    if "developing" in (a,b): return 0
    if "allCourt" in (a,b): return 7
    return -3 if a==b else 10
def evaluate(ul,ua,pl,pa,lefty):
    has_profile = ul is not None and ua is not None
    gap = abs(ul-pl) if (ul is not None and pl is not None) else None
    sf  = fit(ua,pa) if (ua is not None and pa is not None) else None
    if gap is not None and gap<=1 and sf is not None and sf>=7: tier="great"
    elif (gap or 0)>=3 or ((sf or 0)<0 and (gap or 0)>=2): tier="work"
    else: tier="solid"
    return tier, has_profile

# tam profil dağılımı
full=[evaluate(*c) for c in itertools.product(LEVELS,ARCH,LEVELS,ARCH,[False,True])]
dist=collections.Counter(t for t,_ in full)
print("=== TAM PROFİL tier dağılımı (%d komb.) ===" % len(full))
for t in ("great","solid","work"):
    n=dist[t]; print(f"  {t:6s}: {n:5d} ({100*n/len(full):4.1f}%)  {'█'*int(50*n/len(full))}")
# profilsiz
noprof=[evaluate(None,None,pl,pa,lf) for pl,pa,lf in itertools.product(LEVELS,ARCH,[False,True])]
print("profilsiz: hepsi hasProfile=false →", set(hp for _,hp in noprof), "· tier'lar:", set(t for t,_ in noprof))

# GÜVEN ASSERT'LERİ (dürüst tier davranışı)
fails=[]
# 1) 'great' asla zayıf sinyalle çıkmamalı — üretilebilir ama azınlık olmalı
if dist["great"]/len(full) > 0.35: fails.append(f"'great' çok bol (%{100*dist['great']/len(full):.0f}) — dürüst değil")
# 2) 'work' (zorlu eşleşme) gerçekten üretilebilmeli — aksi halde herkes iyi
if dist["work"] == 0: fails.append("'work' hiç çıkmıyor — kötü eşleşme sinyali yok")
# 3) profilsiz kullanıcı asla 'great' iddiası taşımamalı (UI zaten 'profil ekle' der)
if any(t=="great" for t,hp in noprof if not hp): fails.append("profilsizde 'great' iddiası var")
# 4) profilsiz her zaman hasProfile=false döndürmeli (UI degrade edebilsin)
if any(hp for _,hp in noprof): fails.append("profilsizde hasProfile=true sızıyor")
print("\nGÜVEN ASSERT'LERİ:", "YEŞİL ✅" if not fails else "KIRMIZI ⛔")
for f in fails: print("  ✗", f)
sys.exit(1 if fails else 0)
