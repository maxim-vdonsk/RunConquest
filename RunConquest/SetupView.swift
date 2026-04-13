import SwiftUI

// MARK: - Setup

struct SetupView: View {
    @Binding var playerName: String
    @Binding var selectedColor: String
    let onStart: () -> Void

    let colors = ["orange", "blue", "green", "red", "purple"]
    let colorLabels = ["orange": "AMBER", "blue": "CYAN", "green": "MATRIX", "red": "CRIMSON", "purple": "VIOLET"]

    @State private var appeared = false
    @State private var cursor = true

    var accent: Color { Neon.colorMap[selectedColor] ?? Neon.cyan }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()
            CornerBrackets(color: accent)

            VStack(spacing: 28) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: "// SYSTEM INIT //", color: accent)
                    Text("PLAYER REGISTRATION")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                        .shadow(color: accent, radius: 8)
                    NeonDivider(color: accent).padding(.horizontal, 40)
                }
                .offset(y: appeared ? 0 : -20).opacity(appeared ? 1 : 0)

                // Callsign input
                VStack(alignment: .leading, spacing: 8) {
                    NeonLabel(text: "> ENTER CALLSIGN:", color: accent)
                    HStack {
                        TextField("", text: $playerName)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .accentColor(accent)
                        if playerName.isEmpty {
                            Text(cursor ? "█" : " ")
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundColor(accent)
                        }
                    }
                    .padding(14)
                    .background(Neon.surface)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(accent.opacity(playerName.isEmpty ? 0.4 : 0.9), lineWidth: 1)
                            .shadow(color: accent.opacity(0.5), radius: 6)
                    )
                }
                .padding(.horizontal)
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                // Faction color
                VStack(alignment: .leading, spacing: 12) {
                    NeonLabel(text: "> SELECT FACTION:", color: accent).padding(.horizontal)
                    HStack(spacing: 0) {
                        ForEach(colors, id: \.self) { c in
                            let col = Neon.colorMap[c] ?? Neon.cyan
                            let isSelected = selectedColor == c
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(col)
                                    .frame(width: 38, height: 38)
                                    .shadow(color: isSelected ? col : .clear, radius: 12)
                                    .overlay(Circle().stroke(Color.white.opacity(isSelected ? 1 : 0), lineWidth: 2))
                                    .scaleEffect(isSelected ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.25), value: selectedColor)
                                Text(colorLabels[c] ?? "")
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(isSelected ? col : .gray.opacity(0.5))
                                    .shadow(color: isSelected ? col : .clear, radius: 3)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture { selectedColor = c }
                        }
                    }
                    .padding(.horizontal)
                }
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                // Deploy button
                Button(action: onStart) {
                    Text(playerName.isEmpty ? "[ ENTER CALLSIGN ]" : "[ DEPLOY  ▶ ]")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(playerName.isEmpty ? .gray : Neon.bg)
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(playerName.isEmpty ? Color.gray.opacity(0.12) : accent)
                        .cornerRadius(4)
                        .shadow(color: playerName.isEmpty ? .clear : accent.opacity(0.7), radius: 14)
                        .padding(.horizontal)
                }
                .disabled(playerName.isEmpty)
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { appeared = true }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in cursor.toggle() }
        }
    }
}
