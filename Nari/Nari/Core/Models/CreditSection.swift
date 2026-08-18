import Foundation

/// One block of the credits sheet: a heading plus its lines of text.
struct CreditSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let lines: [String]
}
