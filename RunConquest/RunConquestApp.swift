import SwiftUI
import UserNotifications

@main
struct RunConquestApp: App {
    @State private var showSplash = true

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.6), value: showSplash)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    showSplash = false
                }
            }
        }
    }
}

// MARK: - Splash
struct SplashView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowRadius: CGFloat = 10

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Анимированный фоновый круг
            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 350, height: 350)
                .blur(radius: 70)
                .scaleEffect(scale)

            VStack(spacing: 24) {
                ZStack {
                    // Glow
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 130, height: 130)
                        .blur(radius: glowRadius)

                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(
                            colors: [Color.orange, Color(red: 0.9, green: 0.3, blue: 0)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)

                    Text("🏃").font(.system(size: 62))
                }
                .scaleEffect(scale)
                .opacity(opacity)

                VStack(spacing: 4) {
                    Text("RUN")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(10)
                    Text("CONQUEST")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .tracking(7)
                }
                .opacity(opacity)

                Text("Завоюй свой город")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(taglineOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                glowRadius = 25
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
                taglineOpacity = 1.0
            }
        }
    }
}
