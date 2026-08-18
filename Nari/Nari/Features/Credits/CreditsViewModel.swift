import Observation

/// Supplies credits content in the currently selected language.
@MainActor
@Observable
final class CreditsViewModel {
    @ObservationIgnored private let repository: CreditsProviding
    @ObservationIgnored private let settings: SettingsService

    init(repository: CreditsProviding, settings: SettingsService) {
        self.repository = repository
        self.settings = settings
    }

    /// Recomputed whenever the language changes, since reading
    /// `settings.localizer` registers this view for that change.
    var sections: [CreditSection] {
        repository.sections(using: settings.localizer)
    }
}
