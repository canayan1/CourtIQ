import Foundation

/// Bilingual copy for the Tennis Profile feature (EN/TR). Self-contained,
/// mirrors the DoublesCopy pattern. Spanish falls back to English.
struct TennisProfileCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String, _ fr: String? = nil) -> String {
        switch lang {
        case .turkish: return tr
        case .french:  return fr ?? en
        default:       return en
        }
    }

    // MARK: Section / entry
    var sectionTitle: String { t("Tennis Profile", "Tenis Profili", "Profil tennis") }
    var entryTitle: String { t("Discover your tennis profile", "Tenis profilini keşfet", "Découvre ton profil tennis") }
    var entrySubtitle: String {
        t("Answer 12 quick questions to see your level, your style, and what to work on next.", "12 hızlı soruyla seviyeni, stilini ve sıradaki gelişim alanını gör.", "Réponds à 12 questions rapides pour connaître ton niveau, ton style et ce qu'il faut travailler ensuite.")
    }
    var startCTA: String { t("Start the test", "Teste başla", "Commencer le test") }
    var retakeCTA: String { t("Retake the test", "Testi yeniden yap", "Refaire le test") }
    var next: String { t("Next", "İleri", "Suivant") }
    var back: String { t("Back", "Geri", "Retour") }
    var seeProfile: String { t("See my profile", "Profilimi gör", "Voir mon profil") }

    // MARK: Disclaimer (self-rating is provisional)
    var provisionalNote: String {
        t("This is a self-assessment, so treat it as a starting point — most players slightly under-rate themselves. When unsure, pick the higher option.", "Bu bir öz-değerlendirme; başlangıç noktası olarak gör — çoğu oyuncu kendini biraz düşük puanlar. Emin değilsen yükseğini seç.", "C'est une auto-évaluation : prends-la comme un point de départ — la plupart des joueurs se sous-estiment un peu. En cas de doute, choisis l'option supérieure.")
    }

    // MARK: Dimensions
    func dimension(_ d: TennisDimension) -> String {
        switch d {
        case .forehand: return t("Forehand", "Forehand", "Coup droit")
        case .backhand: return t("Backhand", "Backhand", "Revers")
        case .serve:    return t("Serve", "Servis", "Service")
        case .ret:      return t("Return", "Return", "Retour")
        case .net:      return t("Net play / volleys", "File oyunu / vole", "Jeu au filet / volées")
        case .movement: return t("Movement & footwork", "Hareket & ayak işi", "Déplacements et jeu de jambes")
        }
    }
    var scaleWeak: String { t("Shaky", "Zayıf", "Fragile") }
    var scaleStrong: String { t("A weapon", "Silahım", "Une arme") }

    // MARK: Levels
    func levelTitle(_ l: TennisLevel) -> String {
        switch l {
        case .new:          return t("New to tennis", "Tenise yeni", "Débutant")
        case .improver:     return t("Improver", "Gelişen", "En progression")
        case .intermediate: return t("Intermediate", "Orta seviye", "Intermédiaire")
        case .solidClub:    return t("Solid club player", "Sağlam kulüp oyuncusu", "Bon joueur de club")
        case .advancedClub: return t("Advanced club player", "İleri kulüp oyuncusu", "Joueur de club confirmé")
        }
    }
    func levelNTRP(_ l: TennisLevel) -> String {
        switch l {
        case .new:          return "NTRP ~1.5–2.0"
        case .improver:     return "NTRP ~2.5"
        case .intermediate: return "NTRP ~3.0"
        case .solidClub:    return "NTRP ~3.5"
        case .advancedClub: return "NTRP ~4.0+"
        }
    }
    func levelBlurb(_ l: TennisLevel) -> String {
        switch l {
        case .new:          return t("You're learning the strokes and getting the ball in play. Every session builds the base.", "Vuruşları öğreniyor ve topu oyunda tutuyorsun. Her antrenman temeli kuruyor.", "Tu apprends les coups et tu remets la balle en jeu. Chaque séance construit les bases.")
        case .improver:     return t("You can keep a slow rally going; matches are coming together but still inconsistent.", "Yavaş bir ralliyi sürdürebiliyorsun; maçlar oturuyor ama hâlâ değişken.", "Tu tiens un échange lent ; en match, ça vient, mais ce n'est pas encore régulier.")
        case .intermediate: return t("You rally with medium pace fairly consistently — now it's about control and depth.", "Orta tempoyla istikrarlı rally yapıyorsun — şimdi kontrol ve derinlik zamanı.", "Tu échanges à rythme moyen assez régulièrement — place au contrôle et à la profondeur.")
        case .solidClub:    return t("Dependable strokes, you direct the ball, use lobs, and come to the net.", "Güvenilir vuruşlar; topu yönlendiriyor, lob kullanıyor ve fileye geliyorsun.", "Des coups fiables : tu diriges la balle, tu lobes et tu montes au filet.")
        case .advancedClub: return t("Reliable shots with depth and control, and you're adding pace and spin.", "Derinlik ve kontrollü güvenilir vuruşlar; tempo ve spin de ekliyorsun.", "Des coups sûrs, profonds et contrôlés, avec de plus en plus de vitesse et d'effet.")
        }
    }

    // MARK: Archetypes
    func archetypeTitle(_ a: TennisArchetype) -> String {
        switch a {
        case .developing:         return t("Developing player", "Gelişen oyuncu", "Joueur en développement")
        case .aggressiveBaseliner:return t("Aggressive baseliner", "Agresif baseliner", "Joueur de fond de court agressif")
        case .counterpuncher:     return t("Counterpuncher", "Counterpuncher", "Contreur")
        case .allCourt:           return t("All-court player", "All-court oyuncu", "Joueur complet")
        case .serveVolleyer:      return t("Serve-and-volleyer", "Serve-and-volley", "Service-volée")
        }
    }
    func archetypeBlurb(_ a: TennisArchetype) -> String {
        switch a {
        case .developing:          return t("You're building the fundamentals across the board. Pick one or two areas and stack reps.", "Temelleri baştan kuruyorsun. Bir-iki alan seç ve tekrar üstüne tekrar koy.", "Tu construis les fondamentaux partout. Choisis un ou deux domaines et empile les répétitions.")
        case .aggressiveBaseliner: return t("You dictate from the back of the court with your groundstrokes — control + depth turn that into wins.", "Kort arkasından groundstroke'larınla oyunu yönetiyorsun — kontrol + derinlik bunu galibiyete çevirir.", "Tu dictes depuis le fond du court avec tes frappes — contrôle et profondeur transforment ça en victoires.")
        case .counterpuncher:      return t("You move well and outlast opponents with steady, smart balls. Add a way to finish points.", "İyi hareket ediyor, istikrarlı ve akıllı toplarla rakibi yoruyorsun. Puan bitirme yolu ekle.", "Tu te déplaces bien et tu uses tes adversaires avec des balles sûres et intelligentes. Ajoute une façon de conclure.")
        case .allCourt:            return t("You're comfortable everywhere — baseline and net. Use that range to take time away.", "Her yerde rahatsın — baseline ve file. Bu çok yönlülüğü rakibin zamanını çalmak için kullan.", "Tu es à l'aise partout — fond de court et filet. Sers-toi de cette palette pour voler du temps à l'adversaire.")
        case .serveVolleyer:       return t("Your serve and net game set the tone. Sharpen the first volley and the approach.", "Servisin ve file oyunun tempoyu belirliyor. İlk voleyi ve file alışını keskinleştir.", "Ton service et ton jeu au filet donnent le ton. Affûte la première volée et le coup d'approche.")
        }
    }

    // MARK: Result labels
    var levelHeader: String { t("Your level", "Seviyen", "Ton niveau") }
    var styleHeader: String { t("Your style", "Stilin", "Ton style") }
    var strengthsHeader: String { t("Your strengths", "Güçlü yönlerin", "Tes points forts") }
    var growthHeader: String { t("Grow these next", "Sıradaki gelişim", "À développer ensuite") }
    var goalsHeader: String { t("Suggested goals", "Önerilen hedefler", "Objectifs suggérés") }
    var goalsSubhead: String { t("Pick the goals you want to chase — your Coach will help.", "Takip etmek istediğin hedefleri seç — Koç'un yardımcı olur.", "Choisis les objectifs à viser — ton coach t'accompagne.") }
    var adoptGoals: String { t("Save my goals", "Hedeflerimi kaydet", "Enregistrer mes objectifs") }
    var aiTeaser: String { t("Your AI Coach now knows your profile and goals — and will coach you toward them.", "AI Koç'un artık profilini ve hedeflerini biliyor — ve seni onlara doğru yönlendirir.", "Ton Coach IA connaît maintenant ton profil et tes objectifs — et il te coache pour les atteindre.") }
    var myGoalsHeader: String { t("Your goals", "Hedeflerin", "Tes objectifs") }

    // MARK: Re-assess + smart nudge
    /// Sub-label under the re-assess button on the result screen.
    var reassessHint: String {
        t("Your game changes — retake the 12 questions to refresh your level, style and goals.", "Oyunun değişir — 12 soruyu tekrar yanıtlayıp seviyeni, stilini ve hedeflerini tazele.", "Ton jeu évolue — refais les 12 questions pour actualiser ton niveau, ton style et tes objectifs.")
    }
    var reassessCancel: String { t("Cancel", "Vazgeç", "Annuler") }
    var nudgeTitle: String { t("A quick check-in", "Küçük bir kontrol", "Un petit point") }
    /// Shown when recent match results run well ahead of the saved profile.
    func nudgeUp(matches: Int, winPct: Int) -> String {
        t("You've won \(winPct)% of your \(matches) logged matches — you may be playing above your profile. Re-assess?", "Kayıtlı \(matches) maçının %\(winPct)'ini kazandın — profilinin üstünde oynuyor olabilirsin. Yeniden değerlendirelim mi?", "Tu as gagné \(winPct) % de tes \(matches) matchs enregistrés — tu joues peut-être au-dessus de ton profil. On réévalue ?")
    }
    /// Shown when recent results run well behind the saved profile.
    func nudgeDown(matches: Int, winPct: Int) -> String {
        t("Your \(matches) logged matches have been tough (\(winPct)% wins). Let's recalibrate your profile and goals.", "Kayıtlı \(matches) maçın zorlu geçti (%\(winPct) galibiyet). Profilini ve hedeflerini yeniden ayarlayalım.", "Tes \(matches) matchs enregistrés ont été durs (\(winPct) % de victoires). Recalibrons ton profil et tes objectifs.")
    }

    // MARK: Goals (coaching-standard development priorities)
    func goalTitle(_ key: String) -> String {
        switch key {
        case "goal.serve.title":       return t("Build a reliable second serve", "Güvenilir bir ikinci servis kur", "Construire une deuxième balle fiable")
        case "goal.return.title":      return t("Get more returns deep and in play", "Daha çok return'ü derin ve oyunda tut", "Remettre plus de retours longs et en jeu")
        case "goal.forehand.title":    return t("Make the forehand a steady weapon", "Forehand'i istikrarlı bir silaha çevir", "Faire du coup droit une arme régulière")
        case "goal.backhand.title":    return t("Make the backhand dependable", "Backhand'i güvenilir kıl", "Rendre le revers fiable")
        case "goal.net.title":         return t("Finish points at the net", "Puanları filede bitir", "Conclure les points au filet")
        case "goal.movement.title":    return t("Move and recover better", "Daha iyi hareket et ve toparlan", "Mieux se déplacer et se replacer")
        case "goal.compete.title":     return t("Win more of your matches", "Maçlarının daha çoğunu kazan", "Gagner plus de matchs")
        case "goal.technique.title":   return t("Sharpen your technique", "Tekniğini keskinleştir", "Affûter ta technique")
        case "goal.fitness.title":     return t("Build tennis fitness", "Tenis kondisyonu geliştir", "Construire ta condition tennis")
        case "goal.consistency.title": return t("Cut your unforced errors", "Zorlanmamış hataları azalt", "Réduire tes fautes directes")
        case "goal.fun.title":         return t("Play more and enjoy it", "Daha çok oyna ve keyfini çıkar", "Jouer plus et y prendre du plaisir")
        default: return key
        }
    }
    func goalDetail(_ key: String) -> String {
        switch key {
        case "goal.serve.detail":       return t("Aim for ~75% second serves in with a little spin — a steady second serve removes free points.", "Hafif spinle ikinci servislerin ~%75'ini içeri at — sağlam ikinci servis bedava puanları keser.", "Vise environ 75 % de deuxièmes balles en jeu avec un peu d'effet — une deuxième balle sûre supprime les points offerts.")
        case "goal.return.detail":      return t("Just get it back deep and crosscourt — a return in play starts the point on your terms.", "Sadece derin ve çapraz geri koy — oyunda kalan return puanı senin şartlarında başlatır.", "Remets simplement long et croisé — un retour en jeu démarre le point à tes conditions.")
        case "goal.forehand.detail":    return t("Rally 10 crosscourt forehands in a row with topspin for margin.", "Marj için topspinle 10 çapraz forehand'i üst üste rally yap.", "Enchaîne 10 coups droits croisés d'affilée en lift pour la marge.")
        case "goal.backhand.detail":    return t("Make it a dependable rally ball; a reliable slice keeps you in points.", "Onu güvenilir bir rally topu yap; sağlam bir slice seni puanda tutar.", "Fais-en une balle d'échange fiable ; un slice sûr te maintient dans le point.")
        case "goal.net.detail":         return t("Close the net on short balls and put away the first volley.", "Kısa toplarda fileyi kapat ve ilk voleyi bitir.", "Monte au filet sur les balles courtes et conclus la première volée.")
        case "goal.movement.detail":    return t("Split-step on every opponent contact and recover to the middle after each shot.", "Rakip her vuruşta split-step yap ve her vuruştan sonra ortaya toparlan.", "Fais un split-step à chaque frappe adverse et replace-toi au centre après chaque coup.")
        case "goal.compete.detail":     return t("Log your matches and review what wins and loses points for you.", "Maçlarını logla ve sana puan kazandıran/kaybettiren şeyleri gözden geçir.", "Enregistre tes matchs et regarde ce qui te fait gagner ou perdre des points.")
        case "goal.technique.detail":   return t("Pick one stroke and drill it with focus each session.", "Bir vuruş seç ve her antrenmanda bilinçli çalış.", "Choisis un coup et travaille-le avec attention à chaque séance.")
        case "goal.fitness.detail":     return t("Follow a training block so you're still moving well late in matches.", "Bir antrenman bloğu uygula ki maç sonunda hâlâ iyi hareket edesin.", "Suis un bloc d'entraînement pour te déplacer encore bien en fin de match.")
        case "goal.consistency.detail": return t("Target rallies of 10+ balls before you go for a winner.", "Vinner denemeden önce 10+ toplu ralliler hedefle.", "Vise des échanges de 10 balles ou plus avant de tenter le coup gagnant.")
        case "goal.fun.detail":         return t("Keep a simple streak going — consistency beats intensity.", "Basit bir seri tut — istikrar yoğunluğu yener.", "Garde une série simple en vie — la régularité bat l'intensité.")
        default: return key
        }
    }

    // MARK: Questionnaire prompts
    var qExperience: String { t("How long have you played tennis?", "Ne kadar süredir tenis oynuyorsun?", "Depuis combien de temps joues-tu au tennis ?") }
    var qFrequency: String { t("How often do you play now?", "Şu an ne sıklıkla oynuyorsun?", "À quelle fréquence joues-tu en ce moment ?") }
    var qMatch: String { t("Do you play matches?", "Maç oynuyor musun?", "Joues-tu des matchs ?") }
    var qLevel: String { t("Which best describes your game right now?", "Oyununu şu an en iyi hangisi anlatır?", "Qu'est-ce qui décrit le mieux ton jeu aujourd'hui ?") }
    var qStrokesHeader: String { t("Rate your shots", "Vuruşlarını puanla", "Note tes coups") }
    var qStrokesIntro: String { t("1 = shaky, 5 = a weapon you trust.", "1 = zayıf, 5 = güvendiğin bir silah.", "1 = fragile, 5 = une arme en laquelle tu as confiance.") }
    var qPressure: String { t("In a tight game, you usually…", "Çekişmeli bir oyunda genelde…", "Dans un jeu serré, en général tu…") }
    var qWant: String { t("What do you want most from tennis right now?", "Tenisten şu an en çok ne istiyorsun?", "Qu'attends-tu le plus du tennis en ce moment ?") }

    func experienceOption(_ v: TennisExperience) -> String {
        switch v {
        case .justStarting:    return t("Just starting (weeks / first lessons)", "Yeni başladım (haftalar / ilk dersler)", "Je débute (quelques semaines / premiers cours)")
        case .underOneYear:    return t("Under a year", "Bir yıldan az", "Moins d'un an")
        case .oneToThreeYears: return t("1–3 years", "1–3 yıl", "1 à 3 ans")
        case .threeToTenYears: return t("3–10 years", "3–10 yıl", "3 à 10 ans")
        case .tenPlusYears:    return t("10+ years", "10+ yıl", "Plus de 10 ans")
        }
    }
    func frequencyOption(_ v: PlayFrequency) -> String {
        switch v {
        case .rarely:      return t("A few times a year", "Yılda birkaç kez", "Quelques fois par an")
        case .monthly:     return t("About monthly", "Ayda bir civarı", "Environ une fois par mois")
        case .weekly:      return t("Weekly", "Haftada bir", "Une fois par semaine")
        case .twiceThrice: return t("2–3× a week", "Haftada 2–3", "2 à 3 fois par semaine")
        case .fourPlus:    return t("4+ a week", "Haftada 4+", "4 fois par semaine ou plus")
        }
    }
    func matchOption(_ v: MatchExperience) -> String {
        switch v {
        case .never:         return t("No — just hitting", "Hayır — sadece vuruyorum", "Non — juste des échanges")
        case .socialHits:    return t("Casual hits, a few points", "Rahat vuruşlar, birkaç puan", "Des échanges détendus, quelques points")
        case .casualMatches: return t("Friendly matches", "Dostluk maçları", "Des matchs amicaux")
        case .leagueMatches: return t("Club / league matches", "Kulüp / lig maçları", "Des matchs de club / championnat")
        case .tournaments:   return t("Tournaments", "Turnuvalar", "Des tournois")
        }
    }
    func levelOption(_ v: LevelSelfPlacement) -> String {
        switch v {
        case .learningBasics:     return t("Still learning the basics — getting the ball in play", "Hâlâ temelleri öğreniyorum — topu oyunda tutmak", "J'apprends encore les bases — remettre la balle en jeu")
        case .keepRallyGoing:     return t("I can keep a slow rally going, but matches are inconsistent", "Yavaş ralliyi sürdürebilirim ama maçlar değişken", "Je tiens un échange lent, mais mes matchs sont irréguliers")
        case .consistentMedium:   return t("I rally at medium pace fairly consistently, but lack control/depth", "Orta tempoda epey istikrarlı rally yaparım ama kontrol/derinlik eksik", "J'échange à rythme moyen assez régulièrement, mais il me manque du contrôle et de la profondeur")
        case .dependableDirected: return t("Dependable strokes — I direct the ball, use lobs, come to the net", "Güvenilir vuruşlar — topu yönlendirir, lob kullanır, fileye gelirim", "Des coups fiables — je dirige la balle, je lobe, je monte au filet")
        case .depthControlSpin:   return t("Reliable with depth and control, and some pace/spin", "Derinlik ve kontrollü güvenilir; biraz tempo/spin", "Sûr, avec profondeur et contrôle, et un peu de vitesse et d'effet")
        }
    }
    func pressureOption(_ v: PressureResponse) -> String {
        switch v {
        case .rushErrors:  return t("Rush and make errors", "Acele edip hata yaparım", "Je précipite et je fais des fautes")
        case .playSafe:    return t("Get safe and just keep it in", "Garantiye alıp sadece içeride tutarım", "Je sécurise et je remets simplement")
        case .patientPick: return t("Stay patient and pick my moment", "Sabırlı kalıp anımı kollarım", "Je reste patient et je choisis mon moment")
        case .goForIt:     return t("Back myself and go for it", "Kendime güvenip giderim", "Je me fais confiance et je tente")
        }
    }
    func wantOption(_ v: TennisWant) -> String {
        switch v {
        case .compete:     return t("Compete and win more", "Rekabet & daha çok kazanmak", "Compétiter et gagner plus")
        case .technique:   return t("Sharper technique", "Daha iyi teknik", "Une technique plus affûtée")
        case .fitness:     return t("Get fitter / move better", "Daha fit / daha iyi hareket", "Être plus en forme / mieux me déplacer")
        case .consistency: return t("Be more consistent", "Daha istikrarlı olmak", "Être plus régulier")
        case .fun:         return t("Have fun / play more", "Keyif / daha çok oynamak", "M'amuser / jouer plus")
        }
    }
}
