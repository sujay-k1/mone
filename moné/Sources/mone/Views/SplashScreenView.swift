import SwiftUI

struct SplashScreenView: View {
    private let word = "moné"
    private let startDate = Date()
    private let rowHeight: CGFloat = 92
    private let maxRowAcceleration: CGFloat = 192
    private let accelerationRampDuration: CGFloat = 1.2
    private let hapticPulseCount = 9
    private let hapticStartingInterval: CGFloat = 0.240
    private let hapticMinimumInterval: CGFloat = 0.055
    private let hapticVelocityForMaximumCompression: CGFloat = 130
    private let hapticMaximumIntervalCompression: CGFloat = 0.78
    private let hapticStartingIntensity: CGFloat = 1.0
    private let hapticEndingIntensity: CGFloat = 0.2

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
        .task {
            await runAccelerationHaptics()
        }
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

    private func acceleratedVelocity(elapsed: CGFloat) -> CGFloat {
        let rampDuration = accelerationRampDuration

        if elapsed <= rampDuration {
            return maxRowAcceleration * pow(elapsed, 4) / (4 * pow(rampDuration, 3))
        }

        let rampVelocity = maxRowAcceleration * rampDuration / 4
        let timeAfterRamp = elapsed - rampDuration

        return rampVelocity + maxRowAcceleration * timeAfterRamp
    }

    @MainActor
    private func runAccelerationHaptics() async {
        guard hapticPulseCount > 1 else { return }

        var elapsed: CGFloat = 0

        for index in 0..<hapticPulseCount {
            let velocity = acceleratedVelocity(elapsed: elapsed)
            let normalizedVelocity = min(velocity / hapticVelocityForMaximumCompression, 1)
            let interval = max(
                hapticMinimumInterval,
                hapticStartingInterval * (1 - hapticMaximumIntervalCompression * normalizedVelocity)
            )
            elapsed += interval

            guard await sleep(milliseconds: UInt64(interval * 1_000)) else { return }

            let progress = CGFloat(index) / CGFloat(hapticPulseCount - 1)
            let intensity = hapticStartingIntensity
                + (hapticEndingIntensity - hapticStartingIntensity) * progress
            MoneTactileFeedback.playSplashAccelerationPulse(intensity: intensity)
        }
    }

    private func sleep(milliseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return !Task.isCancelled
        } catch {
            return false
        }
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
