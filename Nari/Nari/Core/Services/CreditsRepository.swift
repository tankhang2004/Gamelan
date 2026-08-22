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
                id: "thanks",
                title: strings[.creditsThanksTitle],
                lines: [strings[.creditsThanksBody]]
            ),
        ]
    }
}
