import Foundation

/// Saves and loads SessionRecords from disk.
///
/// Storage path: ~/Library/Application Support/MeetingAssistant/sessions/
/// Each session is a separate JSON file named YYYY-MM-DD_<uuid>.json
final class SessionMemoryManager {

    static let shared = SessionMemoryManager()

    private let sessionsURL: URL

    private init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        sessionsURL = appSupport
            .appendingPathComponent("MeetingAssistant/sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
    }

    // MARK: - Save

    func save(_ record: SessionRecord) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: record.date)
        let filename = "\(dateString)_\(record.id.uuidString).json"
        let fileURL = sessionsURL.appendingPathComponent(filename)

        let data = try JSONEncoder().encode(record)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Load

    func loadRecent(limit: Int = 10) -> [SessionRecord] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: sessionsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return files
            .sorted { url1, url2 in
                let d1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }
            .prefix(limit)
            .compactMap { url -> SessionRecord? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(SessionRecord.self, from: data)
            }
    }
}
