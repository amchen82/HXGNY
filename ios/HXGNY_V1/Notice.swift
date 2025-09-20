//
//  Notice.swift
//  HXGNY_V1
//
//  Created by Chen Feng on 9/8/25.
//

// Sources/Models/NoticeItem.swift
import Foundation

public struct NoticeItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let date: Date
    public let message: String

    public init(id: UUID = UUID(), date: Date, message: String) {
        self.id = id
        self.date = date
        self.message = message
    }
}

// Sources/Models/NoticeDataProvider.swift
import Foundation

public protocol NoticeDataProvider {
    func load() -> [NoticeItem]                         // cache/bundle
    func refresh(completion: @escaping (Bool) -> Void)  // network -> cache
}

public struct GoogleSheetsNoticeProvider: NoticeDataProvider {
    private let sheetURL: URL?
    public init(sheetURL: URL?) { self.sheetURL = sheetURL }

    // Cache file
    private static var docsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("notices.json")
    }

    public func load() -> [NoticeItem] {
        if let cached = try? Data(contentsOf: Self.docsURL),
           let items = try? JSONDecoder().decode([NoticeItem].self, from: cached) {
            return items.sorted { $0.date > $1.date }
        }
        // optional bundle fallback
        if let url = Bundle.main.url(forResource: "notices", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let items = try? JSONDecoder().decode([NoticeItem].self, from: data) {
            return items.sorted { $0.date > $1.date }
        }
        return []
    }

    public func refresh(completion: @escaping (Bool) -> Void) {
        guard let sheetURL else { completion(false); return }
        URLSession.shared.dataTask(with: sheetURL) { data, _, _ in
            guard let data else { completion(false); return }
            do {
                // Sheet rows as flexible dictionaries -> adapt
                let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                let items: [NoticeItem] = rows.compactMap { row in
                    guard let msgAny = row["message"], let msg = String(describing: msgAny).nilIfBlank else { return nil }
                    let dateStr = (row["date"] as? String) ?? ""
                    let d = Self.parseDate(dateStr) ?? Date()  // fallback to today
                    return NoticeItem(date: d, message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                guard !items.isEmpty else { completion(false); return }
                // Normalize & cache
                let normalized = try JSONEncoder().encode(items)
                try? normalized.write(to: Self.docsURL, options: .atomic)
                completion(true)
            } catch {
                completion(false)
            }
        }.resume()
    }

    // accepted formats: 2025-09-07, 09/07/2025, 9/7/25
    private static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd","MM/dd/yyyy","M/d/yyyy","M/d/yy"] {
            f.dateFormat = fmt
            if let d = f.date(from: s.trimmingCharacters(in: .whitespaces)) { return d }
        }
        return nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// Sources/Store/NoticeStore.swift
import Foundation

public final class NoticeStore: ObservableObject {
    @Published public private(set) var items: [NoticeItem] = []
    @Published public var lastUpdated: Date?

    private let provider: NoticeDataProvider

    public init(provider: NoticeDataProvider) {
        self.provider = provider
        items = provider.load()
    }

    public func refresh() {
        provider.refresh { ok in
            DispatchQueue.main.async {
                if ok {
                    self.items = self.provider.load()
                    self.lastUpdated = Date()
                }
            }
        }
    }
}

// Sources/Views/NoticeListView.swift
import SwiftUI

public struct NoticeListView: View {
    @StateObject var store: NoticeStore

    init(sheetURL: URL?) {
        _store = StateObject(wrappedValue: NoticeStore(
            provider: GoogleSheetsNoticeProvider(sheetURL: sheetURL)
        ))
    }

    public var body: some View {
        NavigationStack {
            if store.items.isEmpty {
                ContentUnavailableView("No Notices", systemImage: "bell", description: Text("Pull to refresh or check back later."))
                    .navigationTitle("Notices")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button { store.refresh() } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                        }
                    }
            } else {
                List(store.items) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(n.date, style: .date)
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(linkify(n.message))
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
                .refreshable { store.refresh() }
                .navigationTitle("Notices")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { store.refresh() } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                    }
                }
            }
        }
    }
}
private func linkify(_ text: String) -> AttributedString {
    let mutable = NSMutableAttributedString(string: text)
    if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        detector.matches(in: text, options: [], range: range).forEach { match in
            if let url = match.url {
                mutable.addAttribute(.link, value: url, range: match.range)
            }
        }
    }
    return AttributedString(mutable)
}
#Preview {
    NoticeListView(sheetURL: nil)
}
