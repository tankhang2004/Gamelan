import Foundation

/// Supplies the credits content. Behind a protocol so the copy can later come
/// from a bundled file or a remote fetch without touching the view model.
protocol CreditsProviding {
    func sections(using strings: Localizer) -> [CreditSection]
}

/// Credits held in code. Names are intentionally placeholders — replace the
/// entries in `teamMembers` and `mentors` with the real people before release.
struct StaticCreditsRepository: CreditsProviding {
    private let teamMembers = [
        "Nama Anggota Tim 1 — Design",
        "Nama Anggota Tim 2 — Engineering",
        "Nama Anggota Tim 3 — Motion & Art",
    ]

    private let mentors = [
        "Nama Guru Tari / Sanggar",
        "Nama Dosen / Mentor Akademik",
    ]

    func sections(using strings: Localizer) -> [CreditSection] {
        [
            CreditSection(
                id: "inspiration",
                title: strings[.creditsInspirationTitle],
                lines: [strings[.creditsInspirationBody]]
            ),
            CreditSection(
                id: "team",
                title: strings[.creditsTeamTitle],
                lines: teamMembers
            ),
            CreditSection(
                id: "mentors",
                title: strings[.creditsMentorsTitle],
                lines: mentors
            ),
            CreditSection(
                id: "thanks",
                title: strings[.creditsThanksTitle],
                lines: [strings[.creditsThanksBody]]
            ),
        ]
    }
}
