import Foundation
import SessionPolicy

/// Local tab order per AeroSpace workspace. Does not change tiling — only the strip.
final class TabOrder {
    private let defaultsKey = "tabOrder.byWorkspace"
    private var byWorkspace: [String: [Int]]

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data)
        {
            byWorkspace = decoded
        } else {
            byWorkspace = [:]
        }
    }

    func apply(_ windows: [Win]) -> [Win] {
        SessionPolicy.applyTabOrder(windows, preferredIDsByWorkspace: byWorkspace)
    }

    func setOrder(ids: [Int], workspace: String) {
        guard !workspace.isEmpty else { return }
        byWorkspace[workspace] = ids
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(byWorkspace) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
