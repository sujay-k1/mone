import SwiftUI

struct SplashScreenView: View {
    private let word = "moné"
    private let startDate = Date()
    private let rowHeight: CGFloat = 92
    private let maxRowAcceleration: CGFloat = 192
    private let accelerationRampDuration: CGFloat = 1.2

    var body: some View {
        GeometryReader { geometry in
            let rowCount = max(Int(ceil(geometry.size.height / rowHeight)) + 4, 9)
            let middleIndex = rowCount / 2

            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)

                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        ForEach(0..<rowCount, id: \.self) { index in
                            let distanceFromMiddle = index - middleIndex
                            let wordCount = wordCount(for: distanceFromMiddle)

                            SplashTextRow(
                                word: word,
                                wordCount: wordCount,
                                highlightedIndex: distanceFromMiddle == 0 ? wordCount / 2 : nil
                            )
                                .frame(height: rowHeight)
                                .offset(x: offset(for: distanceFromMiddle, elapsed: elapsed))
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height + rowHeight * 4)
                    .offset(y: -rowHeight * 2)
                    .clipped()
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func wordCount(for distanceFromMiddle: Int) -> Int {
        abs(distanceFromMiddle).isMultiple(of: 2) ? 5 : 6
    }

    private func offset(for distanceFromMiddle: Int, elapsed: TimeInterval) -> CGFloat {
        guard distanceFromMiddle != 0 else { return 0 }

        let movesRightFirst = distanceFromMiddle > 0
            ? !abs(distanceFromMiddle).isMultiple(of: 2)
            : abs(distanceFromMiddle).isMultiple(of: 2)
        let direction: CGFloat = movesRightFirst ? 1 : -1

        let elapsed = CGFloat(elapsed)
        return direction * acceleratedDistance(elapsed: elapsed)
    }

    private func acceleratedDistance(elapsed: CGFloat) -> CGFloat {
        let rampDuration = accelerationRampDuration

        if elapsed <= rampDuration {
            return maxRowAcceleration * pow(elapsed, 5) / (20 * pow(rampDuration, 3))
        }

        let rampDistance = maxRowAcceleration * pow(rampDuration, 2) / 20
        let rampVelocity = maxRowAcceleration * rampDuration / 4
        let timeAfterRamp = elapsed - rampDuration

        return rampDistance
            + rampVelocity * timeAfterRamp
            + 0.5 * maxRowAcceleration * timeAfterRamp * timeAfterRamp
    }
}

private struct SplashTextRow: View {
    let word: String
    let wordCount: Int
    let highlightedIndex: Int?

    var body: some View {
        HStack(spacing: 24) {
            ForEach(0..<wordCount, id: \.self) { index in
                Text(word)
                    .foregroundStyle(Color.white.opacity(index == highlightedIndex ? 1 : 0.3))
            }
        }
        .font(.system(size: 72, weight: .bold, design: .serif))
        .italic()
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview {
    SplashScreenView()
}
