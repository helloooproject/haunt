import UIKit

/// One saved summon: the rendered image (on disk) + which ghost made it.
struct SavedSummon: Identifiable, Codable, Hashable {
    let id: String
    let file: String            // rendered (haunted) image filename
    var originalFile: String?   // the user's original photo (nil for older saves)
    let preset: String          // ghost name used
    let mode: String            // "Realistic" / "Cinematic"
    let date: Date
}

/// On-device gallery ("The Crypt"). Saves rendered ghosts + metadata; survives relaunch.
@MainActor
final class SummonStore: ObservableObject {
    static let shared = SummonStore()
    @Published private(set) var items: [SavedSummon] = []

    private let dir: URL
    private let indexURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("summons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        indexURL = dir.appendingPathComponent("index.json")
        load()
    }

    func image(for s: SavedSummon) -> UIImage? { UIImage(contentsOfFile: dir.appendingPathComponent(s.file).path) }
    func originalImage(for s: SavedSummon) -> UIImage? {
        guard let f = s.originalFile else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(f).path)
    }

    func save(_ image: UIImage, original: UIImage?, preset: String, mode: String) {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return }
        let id = UUID().uuidString
        let file = "\(id).jpg"
        try? data.write(to: dir.appendingPathComponent(file))
        var origFile: String? = nil
        if let original, let odata = original.jpegData(compressionQuality: 0.9) {
            origFile = "\(id)_orig.jpg"
            try? odata.write(to: dir.appendingPathComponent(origFile!))
        }
        items.insert(SavedSummon(id: id, file: file, originalFile: origFile, preset: preset, mode: mode, date: Date()), at: 0)
        persist()
    }

    func delete(_ s: SavedSummon) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(s.file))
        if let f = s.originalFile { try? FileManager.default.removeItem(at: dir.appendingPathComponent(f)) }
        items.removeAll { $0.id == s.id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([SavedSummon].self, from: data) else { return }
        items = decoded.sorted { $0.date > $1.date }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: indexURL) }
    }
}
