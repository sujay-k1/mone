import SwiftUI

struct SplashScreenView: View {
    private let word = "mone"
    private let rowHeight: CGFloat = 92
    private let horizontalTravel: CGFloat = 54
    private let cycleDuration: TimeInterval = 3.4

    var body: some View {
        GeometryReader { geometry in
            let rowCount = max(Int(ceil(geometry.size.height / rowHeight)) + 4, 9)
            let middleIndex = rowCount / 2

            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let phase = sin((elapsed / cycleDuration) * 2 * .pi)

                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        ForEach(0..<rowCount, id: \.self) { index in
                            SplashTextRow(text: rowText(for: geometry.size.width))
                                .frame(height: rowHeight)
                                .offset(x: offset(for: index, middleIndex: middleIndex, phase: phase))
                        }
                    }
                    .frame(width: geometry.size.width * 1.8, height: geometry.size.height + rowHeight * 4)
                    .offset(y: -rowHeight * 2)
                    .clipped()
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func rowText(for width: CGFloat) -> String {
        let repeatCount = max(Int(width / 130) + 8, 12)
        return Array(repeating: word, count: repeatCount).joined(separator: " ")
    }

    private func offset(for index: Int, middleIndex: Int, phase: Double) -> CGFloat {
        let distanceFromMiddle = index - middleIndex
        guard distanceFromMiddle != 0 else { return 0 }

        let movesRightFirst = distanceFromMiddle > 0
            ? !abs(distanceFromMiddle).isMultiple(of: 2)
            : abs(distanceFromMiddle).isMultiple(of: 2)
        let direction: CGFloat = movesRightFirst ? 1 : -1

        return direction * CGFloat(phase) * horizontalTravel
    }
}

private struct SplashTextRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 72, weight: .bold, design: .serif))
            .italic()
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview {
    SplashScreenView()
}
