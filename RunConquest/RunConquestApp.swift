import SwiftUI
import UserNotifications
import UIKit

@main
struct RunConquestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showSplash = true
    @State private var appLanguage = AppLanguage()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("playerName")        private var playerName: String = ""

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasSeenOnboarding {
                    // Первый запуск — онбординг
                    OnboardingView()
                } else if playerName.isEmpty {
                    // Онбординг пройден, но нет аккаунта — авторизация
                    AuthView()
                } else {
                    // Авторизован — основной экран
                    MainTabView()
                }
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environment(appLanguage)
            .animation(.easeOut(duration: 0.5), value: showSplash)
            .animation(.easeInOut(duration: 0.4), value: hasSeenOnboarding)
            .animation(.easeInOut(duration: 0.4), value: playerName.isEmpty)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    showSplash = false
                }
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        PushNotificationManager.shared.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationManager.shared.didRegister(tokenData: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Push registration failed: \(error.localizedDescription)")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        PushNotificationManager.shared.clearBadge()
    }
}

// MARK: - Cyberpunk Splash

struct SplashView: View {
    @Environment(AppLanguage.self) private var lang
    @State private var scanY: CGFloat = -200
    @State private var opacity: Double = 0
    @State private var glowRadius: CGFloat = 6
    @State private var glitchX: CGFloat = 0
    @State private var showSub = false
    @State private var showStatus = false

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            // Scan line
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, Neon.cyan.opacity(0.12), .clear],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(height: 60)
                .offset(y: scanY)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Glitch logo
                ZStack {
                    Text("RUN").font(.system(size: 80, weight: .black, design: .monospaced))
                        .foregroundColor(Neon.red.opacity(0.35)).offset(x: glitchX + 2)
                    Text("RUN").font(.system(size: 80, weight: .black, design: .monospaced))
                        .foregroundColor(Neon.cyan.opacity(0.35)).offset(x: -glitchX - 2)
                    Text("RUN").font(.system(size: 80, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(14)
                        .shadow(color: Neon.cyan, radius: glowRadius)
                }

                Text("CONQUEST")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundColor(Neon.magenta)
                    .tracking(8)
                    .shadow(color: Neon.magenta, radius: glowRadius)

                NeonDivider(color: Neon.cyan).padding(.horizontal, 60).padding(.vertical, 4)

                if showSub {
                    Text(lang.t("> CONQUER YOUR CITY_", "> ЗАВОЮЙ СВОЙ ГОРОД_"))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Neon.cyan.opacity(0.7))
                        .tracking(2)
                        .transition(.opacity)
                }
                if showStatus {
                    VStack(spacing: 4) {
                        StatusLine(text: lang.t("LOCATION MODULE", "МОДУЛЬ ГЕОЛОКАЦИИ"), delay: 0)
                        StatusLine(text: lang.t("NETWORK LINK", "СЕТЕВОЕ СОЕДИНЕНИЕ"), delay: 0.3)
                        StatusLine(text: lang.t("COMBAT SYSTEM", "БОЕВАЯ СИСТЕМА"), delay: 0.6)
                    }
                    .padding(.top, 8)
                    .transition(.opacity)
                }
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) { opacity = 1 }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { scanY = 900 }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glowRadius = 22 }
            Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                glitchX = CGFloat.random(in: 0...2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { glitchX = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation { showSub = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { showStatus = true }
            }
        }
    }
}

struct StatusLine: View {
    let text: String
    let delay: Double
    @State private var ready = false

    var body: some View {
        HStack(spacing: 8) {
            Text("//")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Neon.cyan.opacity(0.4))
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(ready ? "[ OK ]" : "[ .. ]")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(ready ? Neon.green : Neon.cyan.opacity(0.5))
                .shadow(color: ready ? Neon.green : .clear, radius: 4)
        }
        .padding(.horizontal, 48)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.4) {
                withAnimation { ready = true }
            }
        }
    }
}
