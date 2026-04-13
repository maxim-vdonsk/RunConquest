import SwiftUI

// MARK: - Setup

struct SetupView: View {
    @Binding var playerName: String
    @Binding var selectedColor: String
    let onStart: () -> Void

    @Environment(AppLanguage.self) private var lang

    let colors = ["orange", "blue", "green", "red", "purple"]
    let colorLabelsEN = ["orange": "AMBER", "blue": "CYAN", "green": "MATRIX", "red": "CRIMSON", "purple": "VIOLET"]
    let colorLabelsRU = ["orange": "ЯНТАРЬ", "blue": "ЦИАН", "green": "МАТРИЦА", "red": "БАГРЯНЕЦ", "purple": "ФИОЛЕТ"]

    @State private var appeared = false
    @State private var cursor = true
    @State private var nameError: String? = nil

    var accent: Color { Neon.colorMap[selectedColor] ?? Neon.cyan }

    var isValidName: Bool {
        let t = playerName.trimmingCharacters(in: .whitespaces)
        guard t.count >= 3 && t.count <= 20 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- "))
        return t.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    var nameErrorText: String? {
        let t = playerName.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        if t.count < 3 { return lang.t("Min 3 characters", "Минимум 3 символа") }
        if t.count > 20 { return lang.t("Max 20 characters", "Максимум 20 символов") }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- "))
        if !t.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return lang.t("Only letters, numbers, _ and -", "Только буквы, цифры, _ и -")
        }
        return nil
    }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()
            CornerBrackets(color: accent)

            VStack(spacing: 28) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: lang.t("// SYSTEM INIT //", "// ИНИЦИАЛИЗАЦИЯ //"), color: accent)
                    Text(lang.t("PLAYER REGISTRATION", "РЕГИСТРАЦИЯ ИГРОКА"))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                        .shadow(color: accent, radius: 8)
                    NeonDivider(color: accent).padding(.horizontal, 40)
                }
                .offset(y: appeared ? 0 : -20).opacity(appeared ? 1 : 0)

                // Callsign input
                VStack(alignment: .leading, spacing: 8) {
                    NeonLabel(text: lang.t("> ENTER CALLSIGN:", "> ВВЕДИ ПОЗЫВНОЙ:"), color: accent)
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
                            .stroke(nameErrorText != nil ? Neon.red.opacity(0.8) : accent.opacity(playerName.isEmpty ? 0.4 : 0.9), lineWidth: 1)
                            .shadow(color: accent.opacity(0.5), radius: 6)
                    )

                if let err = nameErrorText {
                    Text(err)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Neon.red.opacity(0.8))
                        .tracking(1)
                }
                }
                .padding(.horizontal)
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                // Faction color
                VStack(alignment: .leading, spacing: 12) {
                    NeonLabel(text: lang.t("> SELECT FACTION:", "> ВЫБЕРИ ФРАКЦИЮ:"), color: accent).padding(.horizontal)
                    HStack(spacing: 0) {
                        ForEach(colors, id: \.self) { c in
                            let col = Neon.colorMap[c] ?? Neon.cyan
                            let isSelected = selectedColor == c
                            let labels = lang.code == "ru" ? colorLabelsRU : colorLabelsEN
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(col)
                                    .frame(width: 38, height: 38)
                                    .shadow(color: isSelected ? col : .clear, radius: 12)
                                    .overlay(Circle().stroke(Color.white.opacity(isSelected ? 1 : 0), lineWidth: 2))
                                    .scaleEffect(isSelected ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.25), value: selectedColor)
                                Text(labels[c] ?? "")
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
                    let canDeploy = isValidName
                    Text(!canDeploy
                         ? lang.t("[ ENTER CALLSIGN ]", "[ ВВЕДИ ПОЗЫВНОЙ ]")
                         : lang.t("[ DEPLOY  ▶ ]", "[ НАЧАТЬ  ▶ ]"))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(!canDeploy ? .gray : Neon.bg)
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(!canDeploy ? Color.gray.opacity(0.12) : accent)
                        .cornerRadius(4)
                        .shadow(color: !canDeploy ? .clear : accent.opacity(0.7), radius: 14)
                        .padding(.horizontal)
                }
                .disabled(!isValidName)
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { appeared = true }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in cursor.toggle() }
        }
    }
}
