import Foundation
import Observation

// MARK: - Realtime Manager

@Observable
@MainActor
class RealtimeManager {
    var otherRuns: [RunRecord] = []
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?

    func connect() {
        Task {
            let existing = await SupabaseService.shared.fetchRuns()
            otherRuns = existing
            guard let url = URL(string: "wss://ryldhypslpxjwjxmbjpt.supabase.co/realtime/v1/websocket?apikey=\(SUPABASE_KEY)&vsn=1.0.0") else { return }
            webSocketTask = URLSession(configuration: .default).webSocketTask(with: url)
            webSocketTask?.resume()
            try? await webSocketTask?.send(.string("""
            {"topic":"realtime:public:runs","event":"phx_join","payload":{"config":{"broadcast":{"self":true},"presence":{"key":""},"postgres_changes":[{"event":"*","schema":"public","table":"runs"}]}},"ref":"1"}
            """))
            pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
                self?.webSocketTask?.send(.string("""
                {"topic":"realtime:public:runs","event":"heartbeat","payload":{},"ref":"ping"}
                """)) { _ in }
            }
            await listenForMessages()
        }
    }

    private func listenForMessages() async {
        guard let task = webSocketTask else { return }
        while true {
            guard let message = try? await task.receive() else { break }
            if case .string(let text) = message { await handleMessage(text) }
        }
    }

    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["payload"] as? [String: Any],
              let dataObj = payload["data"] as? [String: Any] else { return }
        if dataObj["type"] as? String == "UPDATE",
           let record = dataObj["record"] as? [String: Any],
           let id = record["id"] as? String,
           let isActive = record["is_active"] as? Bool, !isActive {
            otherRuns.removeAll { $0.id == id }
            return
        }
        if dataObj["type"] as? String == "INSERT",
           let record = dataObj["record"] as? [String: Any],
           let name = record["player_name"] as? String,
           let coords = record["coordinates"] as? String,
           let color = record["color"] as? String {
            let run = RunRecord(id: record["id"] as? String, player_name: name, coordinates: coords, color: color, created_at: record["created_at"] as? String, is_active: true)
            if !otherRuns.contains(where: { $0.id == run.id }) { otherRuns.insert(run, at: 0) }
        }
    }

    func disconnect() { pingTimer?.invalidate(); webSocketTask?.cancel() }
}
