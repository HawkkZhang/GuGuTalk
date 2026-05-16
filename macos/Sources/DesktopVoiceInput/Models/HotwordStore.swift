import Foundation

struct TextReplacement: Codable, Identifiable, Equatable {
    var id: String { from }
    var from: String
    var to: String
}

@MainActor
final class HotwordStore: ObservableObject {
    @Published private(set) var replacements: [TextReplacement] = []

    private static let storageKey = "textReplacements"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([TextReplacement].self, from: data) {
            self.replacements = decoded
        }
    }

    var isEmpty: Bool { replacements.isEmpty }

    func add(from: String, to: String) {
        let trimmedFrom = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTo = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFrom.isEmpty, !trimmedTo.isEmpty else { return }
        guard !replacements.contains(where: { $0.from == trimmedFrom }) else { return }
        replacements.append(TextReplacement(from: trimmedFrom, to: trimmedTo))
        replacements.sort { $0.from.localizedCompare($1.from) == .orderedAscending }
        save()
    }

    func remove(_ from: String) {
        replacements.removeAll { $0.from == from }
        save()
    }

    func applyReplacements(to text: String) -> String {
        var result = text
        let sorted = replacements.sorted { $0.from.count > $1.from.count }
        for replacement in sorted {
            if result.range(of: replacement.from, options: .caseInsensitive) != nil {
                result = result.replacingOccurrences(of: replacement.from, with: replacement.to, options: .caseInsensitive)
            }
        }
        return result
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(replacements) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
