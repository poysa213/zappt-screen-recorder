import SwiftUI

/// A pill-style toggle with an icon, like the ones in the recording panel.
struct PillToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(Theme.spring) { isOn.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
                ZStack {
                    Capsule()
                        .fill(isOn ? Theme.accent : Theme.separator)
                        .frame(width: 34, height: 20)
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .offset(x: isOn ? 7 : -7)
                }
            }
            .foregroundStyle(isOn ? Theme.textPrimary : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isOn ? Theme.accentSoft : Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The big red record button.
struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(.white.opacity(0.25)).frame(width: 26, height: 26)
                    if isRecording {
                        RoundedRectangle(cornerRadius: 3).fill(.white).frame(width: 11, height: 11)
                    } else {
                        Circle().fill(.white).frame(width: 14, height: 14)
                    }
                }
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.recordRed)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .shadow(color: Theme.recordRed.opacity(hovering ? 0.45 : 0.3), radius: hovering ? 14 : 8, y: 4)
            .scaleEffect(hovering ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.spring, value: hovering)
    }
}

/// A small horizontal audio level meter.
struct LevelMeter: View {
    var level: Float // 0...1
    private let segments = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                let threshold = Float(i) / Float(segments)
                RoundedRectangle(cornerRadius: 1)
                    .fill(color(for: i, active: level > threshold))
                    .frame(height: 10)
            }
        }
        .animation(.linear(duration: 0.08), value: level)
    }

    private func color(for index: Int, active: Bool) -> Color {
        guard active else { return Theme.separator }
        let ratio = Double(index) / Double(segments)
        if ratio > 0.85 { return Theme.recordRed }
        if ratio > 0.65 { return .orange }
        return Theme.accent
    }
}

/// A selectable source-type card (Full Screen / Window / Area / Camera).
struct SourceButton: View {
    let type: CaptureSourceType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.symbol)
                    .font(.system(size: 18, weight: .medium))
                Text(type.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .background(isSelected ? Theme.accentSoft : Theme.background)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A labeled section header used across panels and settings.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
            .tracking(0.5)
    }
}
