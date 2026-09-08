import Foundation

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
        guard !windows.isEmpty else { return windows }
        // Visible set can span one workspace per monitor; order within each workspace.
        var result: [Win] = []
        let grouped = Dictionary(grouping: windows, by: \.workspace)
        // Preserve first-seen workspace order from AeroSpace's list.
        var seenWS: [String] = []
        for win in windows where !seenWS.contains(win.workspace) {
            seenWS.append(win.workspace)
        }
        for ws in seenWS {
            let members = grouped[ws] ?? []
            result.append(contentsOf: sort(members, workspace: ws))
        }
        return result
    }

    func setOrder(ids: [Int], workspace: String) {
        guard !workspace.isEmpty else { return }
        byWorkspace[workspace] = ids
        persist()
    }

    private func sort(_ windows: [Win], workspace: String) -> [Win] {
        guard let preferred = byWorkspace[workspace], !preferred.isEmpty else {
            return windows
        }
        var remaining = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        var ordered: [Win] = []
        ordered.reserveCapacity(windows.count)
        for id in preferred {
            if let win = remaining.removeValue(forKey: id) {
                ordered.append(win)
            }
        }
        // New windows keep AeroSpace relative order at the end.
        for win in windows where remaining[win.id] != nil {
            ordered.append(win)
            remaining.removeValue(forKey: win.id)
        }
        return ordered
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(byWorkspace) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
