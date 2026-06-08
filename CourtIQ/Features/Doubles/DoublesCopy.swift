import Foundation

/// Bilingual copy for the Doubles feature (EN/TR). Self-contained; Spanish
/// falls back to English (no es.lproj ships).
struct DoublesCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String) -> String { lang == .turkish ? tr : en }

    // MARK: Section / home
    var sectionTitle: String { t("Doubles", "Çiftler") }
    var homeTitle: String { t("Doubles compatibility", "Çiftler uyumu") }
    var homeSubtitle: String {
        t("See how you and a partner play together — tactically and as teammates.",
          "Bir partnerle nasıl oynadığını gör — hem taktik hem takım olarak.")
    }
    var emptyTitle: String { t("Test a partnership", "Bir partnerliği test et") }
    var emptyBody: String {
        t("You each answer 9 quick questions. Get a tactical + chemistry score, your team setup, and a plan.",
          "İkiniz de 9 hızlı soru yanıtlarsınız. Taktik + kimya skoru, takım kurulumu ve bir plan alın.")
    }
    var newTestCTA: String { t("New compatibility test", "Yeni uyum testi") }
    var partnershipsHeader: String { t("Your partnerships", "Partnerliklerin") }
    func testedOn(_ s: String) -> String { t("Tested \(s)", "Test: \(s)") }

    // MARK: Questionnaire
    var partnerNamePrompt: String { t("Who are you testing with?", "Kiminle test ediyorsun?") }
    var partnerNamePlaceholder: String { t("Partner's name", "Partnerin adı") }
    var youShort: String { t("You", "Sen") }
    var next: String { t("Next", "İleri") }
    var back: String { t("Back", "Geri") }
    var seeResult: String { t("See result", "Sonucu gör") }
    var serveStrengthLabel: String { t("Serve strength", "Servis gücü") }
    var returnStrengthLabel: String { t("Return strength", "Return gücü") }
    var scaleWeak: String { t("Weak", "Zayıf") }
    var scaleStrong: String { t("Strong", "Güçlü") }

    func handoffTitle(_ name: String) -> String { t("Pass the phone to \(name)", "Telefonu \(name)'e ver") }
    func handoffBody(_ name: String) -> String {
        t("\(name) answers the same 9 questions as themselves. Your answers stay private.",
          "\(name) aynı 9 soruyu kendisi için yanıtlar. Senin cevapların gizli kalır.")
    }
    func handoffCTA(_ name: String) -> String { t("Start \(name)'s answers", "\(name) cevaplarına başla") }
    var answeringAsYou: String { t("Answering as you", "Sen olarak cevaplıyorsun") }
    func answeringAsPartner(_ name: String) -> String { t("Answering as \(name)", "\(name) olarak cevaplıyorsun") }

    var sectionTacticalQ: String { t("On court", "Sahada") }
    var sectionChemistryQ: String { t("As teammates", "Takım olarak") }

    func prompt(_ d: DoublesDimension) -> String {
        switch d {
        case .courtSide:   return t("Which return side do you prefer?", "Hangi return tarafını tercih edersin?")
        case .netBaseline: return t("Where are you most comfortable?", "Nerede daha rahatsın?")
        case .handedness:  return t("Which hand do you play with?", "Hangi elle oynarsın?")
        case .formation:   return t("I-formation / Australian?", "I-formation / Australian?")
        case .serve:       return "" // serve/return strength rows
        case .comms:       return t("How much do you talk on court?", "Kortta ne kadar konuşursun?")
        case .temperament: return t("Your on-court temperament?", "Kortta mizacın nasıl?")
        case .goal:        return t("What do you want from doubles?", "Çiftlerden ne istiyorsun?")
        }
    }

    func sideOption(_ v: DoublesSide) -> String {
        switch v { case .deuce: return t("Deuce", "Deuce"); case .ad: return t("Ad", "Ad"); case .either: return t("No preference", "Farketmez") }
    }
    func netOption(_ v: NetComfort) -> String {
        switch v {
        case .net: return t("I love the net", "Filede severim")
        case .mixed: return t("Mixed / all-court", "Karma / all-court")
        case .baseline: return t("I prefer the baseline", "Baseline'ı tercih ederim")
        }
    }
    func handOption(_ v: Handedness) -> String {
        switch v { case .right: return t("Right", "Sağ"); case .left: return t("Left", "Sol") }
    }
    func formationOption(_ v: FormationComfort) -> String {
        switch v { case .flexible: return t("Comfortable", "Rahatım"); case .standardOnly: return t("Standard only", "Sadece standart") }
    }
    func commsOption(_ v: CommStyle) -> String {
        switch v {
        case .vocal: return t("Very vocal", "Çok konuşkan")
        case .moderate: return t("Some", "Orta")
        case .quiet: return t("Quiet", "Sessiz")
        }
    }
    func temperamentOption(_ v: Temperament) -> String {
        switch v {
        case .calm: return t("Calm — I stay steady", "Sakin — dengeli kalırım")
        case .balanced: return t("Balanced", "Dengeli")
        case .fiery: return t("Fiery — I fire up", "Ateşli — parlarım")
        }
    }
    func goalOption(_ v: DoublesGoal) -> String {
        switch v {
        case .win: return t("Compete & win", "Rekabet & kazanmak")
        case .improve: return t("Get better", "Gelişmek")
        case .fun: return t("Fun & social", "Keyif & sosyal")
        }
    }

    /// One player's answer for a dimension (for the transparent breakdown).
    func answer(_ d: DoublesDimension, _ p: DoublesProfile) -> String {
        switch d {
        case .courtSide:   return sideOption(p.preferredSide)
        case .netBaseline: return netOption(p.netComfort)
        case .handedness:  return handOption(p.handedness)
        case .formation:   return formationOption(p.formation)
        case .serve:       return "\(t("serve", "servis")) \(p.serveStrength)/5"
        case .comms:       return commsOption(p.comms)
        case .temperament: return temperamentOption(p.temperament)
        case .goal:        return goalOption(p.goal)
        }
    }

    // MARK: Result
    var tacticalScoreLabel: String { t("Tactical fit", "Taktik uyum") }
    var chemistryScoreLabel: String { t("Chemistry", "Kimya") }
    var overallLabel: String { t("Overall", "Genel") }

    func band(_ b: CompatBand) -> String {
        switch b {
        case .strong: return t("Strong fit", "Güçlü uyum")
        case .workable: return t("Workable", "Çalışılır")
        case .needsPlan: return t("Needs a plan", "Plan gerek")
        }
    }
    func bandBlurb(_ b: CompatBand) -> String {
        switch b {
        case .strong: return t("Your games and your styles line up. Lean into it.", "Oyununuz ve tarzınız örtüşüyor. Üstüne gidin.")
        case .workable: return t("A solid base with a few things to align on.", "Sağlam bir temel — birkaç noktada anlaşın.")
        case .needsPlan: return t("Some clashes to manage. The plan below helps.", "Yönetilecek çakışmalar var. Aşağıdaki plan yardımcı olur.")
        }
    }

    func dimTitle(_ d: DoublesDimension) -> String {
        switch d {
        case .courtSide:   return t("Court sides", "Kort tarafları")
        case .netBaseline: return t("Net coverage", "File kapsama")
        case .handedness:  return t("Handedness", "El kombinasyonu")
        case .formation:   return t("Formation range", "Formasyon esnekliği")
        case .serve:       return t("Serving", "Servis")
        case .comms:       return t("Communication", "İletişim")
        case .temperament: return t("Temperament", "Mizaç")
        case .goal:        return t("Goals", "Hedefler")
        }
    }

    func dimNote(_ d: DoublesDimension, _ r: DimensionRating) -> String {
        switch (d, r) {
        case (.courtSide, .green):   return t("Your return sides fit cleanly.", "Return taraflarınız temiz oturuyor.")
        case (.courtSide, .yellow):  return t("Both flexible — just agree on sides.", "İkiniz de esneksiniz — tarafları konuşun.")
        case (.courtSide, .red):     return t("You both want the same side; one must adapt.", "İkiniz de aynı tarafı istiyorsunuz; biri uyum sağlamalı.")
        case (.netBaseline, .green): return t("Good balance — someone owns the net.", "İyi denge — biri fileyi sahipleniyor.")
        case (.netBaseline, .yellow):return t("Manageable, but cover the net together.", "İdare eder ama fileyi birlikte kapatın.")
        case (.netBaseline, .red):   return t("Both baseline-heavy — weak at the net.", "İkiniz de baseline ağırlıklı — filede zayıf.")
        case (.handedness, .green):  return t("Lefty + righty — two forehands in the middle.", "Sol + sağ — ortada iki forehand.")
        case (.handedness, .yellow): return t("Same hand — mind the backhand in the middle.", "Aynı el — ortadaki backhand'e dikkat.")
        case (.handedness, .red):    return t("Same hand.", "Aynı el.")
        case (.formation, .green):   return t("You can both run I-formation / Australian.", "İkiniz de I-formation / Australian oynayabilirsiniz.")
        case (.formation, .yellow):  return t("Limited tactical variety for now.", "Şimdilik sınırlı taktik çeşitlilik.")
        case (.formation, .red):     return t("Standard formation only.", "Sadece standart formasyon.")
        case (.serve, .green):       return t("Two dependable serves.", "İki güvenilir servis.")
        case (.serve, .yellow):      return t("Serving is a work-in-progress.", "Servis gelişime açık.")
        case (.serve, .red):         return t("Serve is a weak point for the team.", "Servis takım için zayıf nokta.")
        case (.comms, .green):       return t("You'll talk enough to avoid confusion.", "Kafa karışıklığını önleyecek kadar konuşursunuz.")
        case (.comms, .yellow):      return t("One of you should make the calls.", "Biriniz çağrıları yapmalı.")
        case (.comms, .red):         return t("Both quiet — middle balls will get messy.", "İkiniz de sessiz — orta toplar karışır.")
        case (.temperament, .green): return t("Your temperaments balance each other.", "Mizaçlarınız birbirini dengeliyor.")
        case (.temperament, .yellow):return t("One runs hot — keep each other level.", "Biri çabuk parlıyor — birbirinizi dengede tutun.")
        case (.temperament, .red):   return t("Two hotheads — you'll need a reset routine.", "İki ateşli — bir sakinleşme rutini gerekecek.")
        case (.goal, .green):        return t("You want the same thing from doubles.", "Çiftlerden aynı şeyi istiyorsunuz.")
        case (.goal, .yellow):       return t("Slightly different goals — talk expectations.", "Hedefleriniz biraz farklı — beklentileri konuşun.")
        case (.goal, .red):          return t("One's here to win, one's here for fun — real friction risk.", "Biri kazanmak biri keyif için — gerçek sürtüşme riski.")
        }
    }

    // MARK: Team setup (with reasons)
    var teamSetupHeader: String { t("Your team setup", "Takım kurulumun") }
    func serveFirstLine(server: String, serverServe: Int, other: Int) -> String {
        if serverServe == other {
            return t("\(server) or either can serve first — your serves are level.",
                     "\(server) ya da herhangi biri önce servis atabilir — servisleriniz eşit.")
        }
        return t("\(server) serves first — stronger serve (\(serverServe) vs \(other)); more service games if the set runs long.",
                 "Önce \(server) servis atar — daha güçlü servis (\(serverServe)'e \(other)); set uzarsa daha çok servis oyunu.")
    }
    func returnLine(deuce: String, ad: String, clash: Bool) -> String {
        if clash {
            return t("\(ad) returns ad, \(deuce) returns deuce — the more clutch returner takes the ad court, where more big points are decided.",
                     "\(ad) ad döner, \(deuce) deuce döner — daha clutch return ad tarafını alır; kritik puanların çoğu orada.")
        }
        return t("\(deuce) returns deuce, \(ad) returns ad — your stated side preferences.",
                 "\(deuce) deuce döner, \(ad) ad döner — belirttiğiniz taraf tercihleri.")
    }
    func formationLine(_ f: StartingFormation) -> String {
        switch f {
        case .bothUp:            return t("Start both at the net — you both like it there; close as a wall.", "İkiniz de filede başlayın — ikiniz de seviyorsunuz; duvar gibi kapatın.")
        case .oneUpOneBackPoach: return t("One up, one back — the net player poaches the middle.", "Biri önde biri arkada — file oyuncusu ortayı poach'lar.")
        case .startBackApproach: return t("Start back, then approach together on short balls.", "Arkada başlayın, kısa toplarda birlikte file alın.")
        }
    }

    var strengthsHeader: String { t("Strengths", "Güçlü yönler") }
    var watchOutsHeader: String { t("Watch-outs", "Dikkat edilecekler") }

    // MARK: Prep sheet
    var prepHeader: String { t("Practice plan", "Antrenman planı") }
    func prepTip(_ d: DoublesDimension) -> String {
        switch d {
        case .courtSide:   return t("Rehearse the I-formation so the server's partner doesn't telegraph the side.", "I-formation'ı çalışın ki servis atanın partneri tarafı ele vermesin.")
        case .netBaseline: return t("Drill approaching together on short balls and closing the net as a pair.", "Kısa toplarda birlikte file alıp çift olarak fileyi kapatmayı çalışın.")
        case .handedness:  return t("Cover the middle deliberately — decide whose shot it is before the point.", "Ortayı bilinçli kapatın — top kimin, puandan önce belirleyin.")
        case .formation:   return t("Add I-formation and Australian against strong cross-court returners.", "Güçlü çapraz return'cülere karşı I-formation ve Australian ekleyin.")
        case .serve:       return t("Build first-serve consistency; a steady serve sets up the whole point in doubles.", "İlk servis istikrarını geliştirin; sağlam servis tüm puanı kurar.")
        case .comms:       return t("Pre-agree: the middle ball belongs to the forehand / the player moving to it.", "Önceden anlaşın: orta top forehand'in / o yöne hareket edenin.")
        case .temperament: return t("Agree a reset routine (a word, a breath) for after a bad point so frustration doesn't snowball.", "Kötü puandan sonra bir sakinleşme rutini (bir kelime, bir nefes) belirleyin ki gerginlik büyümesin.")
        case .goal:        return t("Talk before you play: are today's matches about winning, improving, or fun? Match the intensity.", "Oynamadan önce konuşun: bugünkü maçlar kazanmak mı, gelişmek mi, keyif mi? Tempoyu ona göre ayarlayın.")
        }
    }

    // MARK: AI plan (premium teaser; Step 6)
    var aiPlanTitle: String { t("AI doubles game-plan", "AI çiftler oyun planı") }
    var aiPlanBody: String {
        t("A personalized plan from the AI Coach — built around your two profiles, your matches, and your weak spots.",
          "AI Koç'tan kişisel bir plan — iki profilinize, maçlarınıza ve zayıf yönlerinize göre.")
    }
    var aiPlanComingSoon: String { t("Coming soon", "Yakında") }

    // MARK: Invite / Join (account-linked)
    var inviteCTA: String { t("Invite a partner", "Partner davet et") }
    var joinCTA: String { t("I have an invite code", "Davet kodum var") }
    var singleDeviceCTA: String { t("Test on this phone", "Bu telefonda test et") }

    var yourNamePrompt: String { t("How should your partner see you?", "Partnerin seni nasıl görsün?") }
    var yourNamePlaceholder: String { t("Your name", "Adın") }

    var inviteTitle: String { t("Invite a partner", "Partner davet et") }
    var inviteIntro: String {
        t("Answer your 9 questions, then send your partner a link. They install CourtIQ, answer theirs, and you both see the score.",
          "9 soruyu yanıtla, sonra partnerine link gönder. CourtIQ'i indirip kendi sorularını yanıtlar; ikiniz de skoru görürsünüz.")
    }
    var createInviteCTA: String { t("Create invite link", "Davet linki oluştur") }
    var inviteReadyTitle: String { t("Invite ready", "Davet hazır") }
    var inviteReadyBody: String {
        t("Send this to your partner. The moment they join, your compatibility score appears in your partnerships.",
          "Bunu partnerine gönder. Katıldığı an uyum skorunuz partnerliklerinde görünür.")
    }
    var inviteCodeLabel: String { t("Invite code", "Davet kodu") }
    var shareInvite: String { t("Share link", "Linki paylaş") }
    func inviteShareMessage(link: String, code: String) -> String {
        t("Let's check our doubles chemistry on CourtIQ 🎾\n\(link)\n(or enter code \(code) in the app)",
          "CourtIQ'te çiftler uyumumuza bakalım 🎾\n\(link)\n(ya da uygulamada \(code) kodunu gir)")
    }
    var done: String { t("Done", "Bitti") }

    var joinTitle: String { t("Join with a code", "Kodla katıl") }
    var joinCodePrompt: String { t("Enter the invite code your partner sent", "Partnerinin gönderdiği davet kodunu gir") }
    var joinCodePlaceholder: String { t("Invite code", "Davet kodu") }
    var lookUp: String { t("Continue", "Devam") }
    func invitedByLine(_ name: String) -> String { t("\(name) invited you to a doubles test.", "\(name) seni bir çiftler testine davet etti.") }
    var someoneInvitedYou: String { t("You've been invited to a doubles test.", "Bir çiftler testine davet edildin.") }
    var joinSeeScore: String { t("Join & see score", "Katıl & skoru gör") }

    var pendingBadge: String { t("Waiting for partner", "Partner bekleniyor") }
    var pendingNote: String { t("Waiting for your partner to join.", "Partnerinin katılması bekleniyor.") }
    var inviteNotFound: String { t("That code didn't match an open invite.", "Bu kod açık bir davetle eşleşmedi.") }
    var serverPartnershipsHeader: String { t("Linked partnerships", "Bağlı partnerlikler") }
    var localPartnershipsHeader: String { t("On this phone", "Bu telefonda") }
    var chooseHowTitle: String { t("Start a test", "Bir test başlat") }

    // MARK: misc
    var deletePartnership: String { t("Delete", "Sil") }
}
