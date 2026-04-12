import SwiftUI

// MARK: - Setup

struct SetupView: View {
    @Binding var playerName: String
    @Binding var selectedColor: String
    let onStart: () -> Void
    let colors = ["orange", "blue", "green", "red", "purple"]
    let colorMap: [String: Color] = ["orange": .orange, "blue": .blue, "green": .green, "red": .red, "purple": .purple]
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("RUN CONQUEST")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.orange).tracking(3)
                    Text("⚔️ Завоюй свой город").font(.caption).foregroundColor(.gray)
                }
                .offset(y: appeared ? 0 : -30).opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Твоё имя").foregroundColor(.gray).font(.caption)
                    TextField("Введи имя...", text: $playerName)
                        .padding().background(Color.white.opacity(0.1))
                        .cornerRadius(12).foregroundColor(.white)
                }
                .padding(.horizontal)
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Цвет твоей зоны").foregroundColor(.gray).font(.caption).padding(.horizontal)
                    HStack(spacing: 16) {
                        ForEach(colors, id: \.self) { color in
                            Circle().fill(colorMap[color] ?? .orange).frame(width: 44, height: 44)
                                .overlay(Circle().stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0))
                                .scaleEffect(selectedColor == color ? 1.15 : 1.0)
                                .animation(.spring(response: 0.3), value: selectedColor)
                                .onTapGesture { selectedColor = color }
                        }
                    }.padding(.horizontal)
                }
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                Button(action: onStart) {
                    Text("НАЧАТЬ ИГРУ").bold().tracking(2).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding()
                        .background(playerName.isEmpty ? Color.gray : Color.orange)
                        .cornerRadius(16).padding(.horizontal)
                        .shadow(color: .orange.opacity(playerName.isEmpty ? 0 : 0.4), radius: 12)
                }
                .disabled(playerName.isEmpty)
                .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appeared = true }
        }
    }
}
