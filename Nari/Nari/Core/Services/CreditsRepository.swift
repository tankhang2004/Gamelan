import Foundation

/// Supplies the credits content. Behind a protocol so the copy can later come
/// from a bundled file or a remote fetch without touching the view model.
protocol CreditsProviding {
    func sections(using strings: Localizer) -> [CreditSection]
}

struct StaticCreditsRepository: CreditsProviding {
    func sections(using strings: Localizer) -> [CreditSection] {
        [
            CreditSection(
                id: "about",
                title: strings[.creditsAboutTitle],
                lines: [strings[.creditsAboutBody]]
            ),
            CreditSection(
                id: "howToPlay",
                title: strings[.creditsHowToPlayTitle],
                lines: [
                    strings[.creditsHowToPlayStep1],
                    strings[.creditsHowToPlayStep2],
                    strings[.creditsHowToPlayStep3],
                    strings[.creditsHowToPlayStep4],
                    strings[.creditsHowToPlayStep5],
                ]
            ),
            CreditSection(
                id: "credits",
                title: strings[.creditsCreditsTitle],
                lines: [strings[.creditsCreditsBody]]
            ),
        ]
    }
}
