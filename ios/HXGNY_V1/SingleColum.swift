//
//  SingleColum.swift
//  HXGNYV1
//
//  Created by Chen Feng on 9/14/25.
//


// Sources/Models/OneColumnItem.swift
import Foundation

public struct OneColumnItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}



// Sources/Models/OneColumnDataProvider.swift
import Foundation

public protocol OneColumnDataProvider {
    func load() -> [OneColumnItem]                         // cache/bundle
    func refresh(completion: @escaping (Bool) -> Void)      // network -> cache
}

/// Generic one-column provider for OpenSheet / Apps Script JSON
/// Example endpoint: https://opensheet.vercel.app/<SHEET_ID>/<TAB_NAME>
public struct GoogleSheetsOneColumnProvider: OneColumnDataProvider {
    private let sheetURL: URL?
    private let columnName: String?        // e.g. "content"; if nil -> first column
    private let slug: String               // unique key per feature (e.g. "join", "events")

    public init(sheetURL: URL?, columnName: String? = nil, slug: String) {
        self.sheetURL = sheetURL
        self.columnName = columnName
        self.slug = slug
    }

    private var docsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("onecol_\(slug).json")
    }
    private var bundleURL: URL? {
        Bundle.main.url(forResource: "onecol_\(slug)", withExtension: "json")
    }
    private var lastUpdatedKey: String { "onecol.\(slug).lastUpdated" }

    public func load() -> [OneColumnItem] {
        if let data = try? Data(contentsOf: docsURL),
           let items = try? JSONDecoder().decode([OneColumnItem].self, from: data) {
            return items
        }
        if let url = bundleURL,
           let data = try? Data(contentsOf: url),
           let items = try? JSONDecoder().decode([OneColumnItem].self, from: data) {
            return items
        }
        return []
    }

    public func refresh(completion: @escaping (Bool) -> Void) {
        guard let sheetURL else { completion(false); return }
        URLSession.shared.dataTask(with: sheetURL) { data, _, _ in
            guard let data else { completion(false); return }
            do {
                let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

                func keyForRow(_ row: [String: Any]) -> String? {
                    if let name = columnName,
                       row.keys.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                        return row.keys.first { $0.caseInsensitiveCompare(name) == .orderedSame }
                    }
                    return row.keys.first // first column if no name provided
                }

                let items: [OneColumnItem] = rows.compactMap { row in
                    guard let key = keyForRow(row), let anyVal = row[key] else { return nil }
                    let text = String(describing: anyVal).trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? nil : OneColumnItem(text: text)
                }

                guard !items.isEmpty else { completion(false); return }
                let normalized = try JSONEncoder().encode(items)
                try? normalized.write(to: docsURL, options: .atomic)
                UserDefaults.standard.set(Date(), forKey: lastUpdatedKey)
                completion(true)
            } catch {
                completion(false)
            }
        }.resume()
    }

    // Expose lastUpdated key so views/stores can read a date
    public func lastUpdatedDate() -> Date? {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }
}


// Sources/Store/OneColumnStore.swift
import Foundation

public final class OneColumnStore: ObservableObject {
    @Published public private(set) var items: [OneColumnItem] = []
    @Published public var lastUpdated: Date?

    private let provider: GoogleSheetsOneColumnProvider

    public init(provider: GoogleSheetsOneColumnProvider, autoRefresh: Bool = true) {
        self.provider = provider
        self.items = provider.load()
        self.lastUpdated = provider.lastUpdatedDate()
        if autoRefresh { refresh() }
    }

    public func refresh() {
        provider.refresh { ok in
            DispatchQueue.main.async {
                if ok {
                    self.items = self.provider.load()
                    self.lastUpdated = self.provider.lastUpdatedDate()
                }
            }
        }
    }
}

// Sources/Views/OneColumnListView.swift
import SwiftUI

public struct OneColumnListView: View {
    @StateObject private var store: OneColumnStore
    private let title: String

    /// - Parameters:
    ///   - title: Nav title to show
    ///   - sheetURL: OpenSheet / Apps Script JSON endpoint
    ///   - slug: unique cache key (e.g. "join", "events")
    ///   - columnName: optional header name (if known); otherwise first column is used
    public init(title: String, sheetURL: URL?, slug: String, columnName: String? = nil) {
        self.title = title
        _store = StateObject(wrappedValue: OneColumnStore(
            provider: GoogleSheetsOneColumnProvider(
                sheetURL: sheetURL,
                columnName: columnName,
                slug: slug
            ),
            autoRefresh: true
        ))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    ContentUnavailableView(title, systemImage: "list.bullet.rectangle",
                                           description: Text("Pull to refresh or check back later."))
                } else {
                    List(store.items) { item in
                        Text(linkify(item.text))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 6)
                    }
                    .refreshable { store.refresh() }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { store.refresh() } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let ts = store.lastUpdated {
                    Text("Last updated: \(ts.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
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
    OneColumnListView(
        title: "Preview",
        sheetURL: nil,
        slug: "preview"
    )
}
