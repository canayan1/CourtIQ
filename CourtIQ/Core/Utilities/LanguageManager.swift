import SwiftUI

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .spanish: return "Español"
        }
    }

    var regionLabel: String {
        switch self {
        case .english: return "EN"
        case .turkish: return "TR"
        case .spanish: return "ES"
        }
    }
}

// MARK: - LanguageManager

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: storageKey) }
    }

    private let storageKey = "CourtIQ.Language"

    private init() {
        // Localization is not yet shipped — locked to English until a future update.
        language = .english
    }

    func t(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            let fallback = Bundle.main.path(forResource: "en", ofType: "lproj")
                .flatMap { Bundle(path: $0) }
            return fallback?.localizedString(forKey: key, value: key, table: nil) ?? key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private func r(_ en: String, _ tr: String, _ es: String) -> String {
        switch language {
        case .english: return en
        case .turkish: return tr
        case .spanish: return es
        }
    }

    // MARK: - Tabs

    var tabToday: String      { r("Today",     "Bugün",        "Hoy") }
    var tabPractice: String   { r("Practice",  "Pratik",       "Práctica") }
    var tabCommunity: String  { r("Community", "Topluluk",     "Comunidad") }
    var tabTraining: String   { r("Training",  "Antrenman",    "Entrenamiento") }
    var tabProfile: String    { r("Profile",   "Profil",       "Perfil") }

    // MARK: - Profile

    var profileTitle: String            { r("Profile",           "Profil",               "Perfil") }
    var sectionProgress: String         { r("Progress",          "İlerleme",             "Progreso") }
    var sectionQuizHistory: String      { r("Quiz History",      "Sınav Geçmişi",        "Historial de Quiz") }
    var sectionAccount: String          { r("Account",           "Hesap",                "Cuenta") }
    var sectionPolicies: String         { r("Policies",          "Politikalar",          "Políticas") }
    var sectionLanguage: String         { r("Language",          "Dil",                  "Idioma") }

    var statDayStreak: String           { r("Day streak",        "Gün serisi",           "Racha de días") }
    var statQuizzesDone: String         { r("Quizzes done",      "Tamamlanan sınav",     "Quiz completados") }
    var statThisWeek: String            { r("This week",         "Bu hafta",             "Esta semana") }
    var statDays: String                { r("days",              "gün",                  "días") }

    var btnSignOut: String              { r("Sign Out",          "Çıkış Yap",            "Cerrar Sesión") }
    var btnDeleteAccount: String        { r("Delete Account",    "Hesabı Sil",           "Eliminar Cuenta") }
    var btnResetData: String            { r("Reset Local Data",  "Yerel Verileri Sıfırla","Restablecer Datos") }
    var btnRestorePurchases: String     { r("Restore Purchases", "Satın Almaları Geri Yükle", "Restaurar Compras") }
    var btnUnlockAllAccess: String      { r("Unlock All Access", "Tam Erişimi Aç",       "Desbloquear Acceso Total") }
    var btnManageSubscription: String   { r("Manage Subscription","Aboneliği Yönet",     "Gestionar Suscripción") }
    var btnViewPlans: String            { r("View All Access Plans","Erişim Planlarını Gör","Ver Planes de Acceso") }

    var premiumBadge: String            { r("Premium",           "Premium",              "Premium") }
    var guestLabel: String              { r("Guest",             "Misafir",              "Invitado") }
    var appleIDLabel: String            { r("Apple ID",          "Apple ID",             "Apple ID") }

    // MARK: - Community

    var communityTitle: String          { r("Discussion",        "Tartışma",             "Discusión") }
    var communityAddTake: String        { r("Add your take",     "Düşünceni paylaş",     "Comparte tu opinión") }
    var communityEditComment: String    { r("Edit comment",      "Yorumu düzenle",       "Editar comentario") }
    var communityEmptyPrompt: String    { r("Be the first to share your take on today's tip.",
                                            "Bu ipucu hakkında ilk yorumu sen yap.",
                                            "Sé el primero en compartir tu opinión sobre el consejo de hoy.") }
    var commentsSuffix: String          { r("comments",          "yorum",                "comentarios") }
    var coachLabel: String              { r("Coach",             "Antrenör",             "Entrenador") }

    // MARK: - Common Actions

    var btnPost: String     { r("Post",     "Gönder",   "Publicar") }
    var btnSave: String     { r("Save",     "Kaydet",   "Guardar") }
    var btnEdit: String     { r("Edit",     "Düzenle",  "Editar") }
    var btnDelete: String   { r("Delete",   "Sil",      "Eliminar") }
    var btnReport: String   { r("Report",   "Bildir",   "Reportar") }
    var btnCancel: String   { r("Cancel",   "İptal",    "Cancelar") }
    var btnOK: String       { r("OK",       "Tamam",    "Aceptar") }
    var btnSaving: String   { r("Saving…",  "Kaydediliyor…", "Guardando…") }

    // MARK: - Paywall / Upsell

    var unlockCommunity: String { r(
        "Sign in with Apple and unlock All Access to join the conversation.",
        "Konuşmaya katılmak için Apple ile giriş yap ve Tam Erişimi aç.",
        "Inicia sesión con Apple y desbloquea el Acceso Total para unirte."
    )}

    var unlockMobility: String { r(
        "Preview is limited to the first two flows. All Access unlocks the full mobility and recovery library.",
        "Önizleme yalnızca ilk iki akış ile sınırlıdır. Tam Erişim ile tüm mobilite kütüphanesini aç.",
        "La vista previa se limita a los dos primeros flujos. Acceso Total desbloquea toda la biblioteca."
    )}
}
