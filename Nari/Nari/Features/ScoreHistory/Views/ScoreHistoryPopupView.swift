import SwiftUI

/// Past runs, newest first, with the personal best marked. Works offline and
/// needs no GameKit, which is why it exists before the leaderboard does.
struct ScoreHistoryPopupView: View {
    let records: [ScoreRecord]
    let onClose: () -> Void

    @Environment(\.strings) private var strings

    private var best: ScoreRecord? { records.max { $0.score < $1.score } }

    var body: some View {
        PopupCard(title: strings[.scoresTitle], onClose: onClose) {
            if records.isEmpty {
                empty
            } else {
                list
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.dance")
                .font(.system(size: 44, weight: .light))
            Text(strings[.scoresEmpty])
                .font(Theme.Fonts.body(19))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.Palette.ink.opacity(0.55))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(records) { record in
                    row(record, isBest: record.id == best?.id)
                }
            }
        }
        .frame(maxHeight: 360)
    }

    private func row(_ record: ScoreRecord, isBest: Bool) -> some View {
        HStack(spacing: 14) {
            if isBest {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Palette.cueOrange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.score)")
                    .font(Theme.Fonts.readout(isBest ? 34 : 27))
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Palette.ink.opacity(0.55))
            }

            Spacer(minLength: 0)

            Text(RunClock.text(for: record.survivedSeconds))
                .font(Theme.Fonts.readout(20))
                .foregroundStyle(Theme.Palette.ink.opacity(0.7))
        }
        .foregroundStyle(Theme.Palette.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isBest ? Theme.Palette.indigo.opacity(0.20) : Theme.Palette.paperShade.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Palette.ink.opacity(isBest ? 0.7 : 0.18), lineWidth: isBest ? 3 : 2)
        )
    }
}

/// Formats a run length as mm:ss. Shared by the HUD timer and the history list
/// so a run reads the same in both places.
enum RunClock {
    static func text(for seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    ZStack {
        PaintTexture()
        ScoreHistoryPopupView(
            records: [
                ScoreRecord(score: 1342, survivedSeconds: 105),
                ScoreRecord(score: 860, survivedSeconds: 71, date: .now.addingTimeInterval(-8000)),
            ],
            onClose: {}
        )
    }
    .ignoresSafeArea()
    .environment(\.strings, Localizer(language: .english))
}
