//# Directory Tree
//
//```
//Sources/
// ├─ Models/
// │   ├─ ClassItem.swift
// │   └─ ClassDataProvider.swift
// ├─ Store/
// │   └─ ClassStore.swift
// ├─ Views/
// │   ├─ ClassListView.swift
// │   ├─ ClassDetailView.swift
// │   ├─ ZoomableImageView.swift
// │   ├─ SplashView.swift
// │   └─ RootTabs.swift
// └─ App/
//     └─ EdgemontClassFinderApp.swift
//Resources/
// ├─ Assets.xcassets/
// │   ├─ BuildingMap.imageset
// │   ├─ ParkingMap.imageset
// │   └─ LaunchLogo.imageset (optional)
// └─ classes.json (optional seed)
//```
//
//---
//
//// MARK: - File: Sources/Models/ClassItem.swift
//```swift

import CryptoKit

func stableUUID(from key: String) -> UUID {
    let hash = SHA256.hash(data: Data(key.utf8))
    var bytes = Array(hash.prefix(16)) // 16 bytes = 128 bits
    // Set version (4) and variant (RFC 4122)
    bytes[6] = (bytes[6] & 0x0F) | 0x40
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}

import Foundation

public struct ClassItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public let title: String
    public let teacher: String
    public let chineseTeacher: String?
    public let day: String
    public let time: String
    public let grade: String
    public let room: String
    public let buildingHint: String?

    public init(
        id: UUID = UUID(),
        title: String,
        teacher: String,
        chineseTeacher: String?,
        day: String,
        time: String,
        grade: String,
        room: String,
        buildingHint: String?
    ) {
        self.id = id
        self.title = title
        self.teacher = teacher
        self.chineseTeacher = chineseTeacher
        self.day = day
        self.time = time
        self.grade = grade
        self.room = room
        self.buildingHint = buildingHint
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // Decode fields first
        let title = try c.decode(String.self, forKey: .title)
        let teacher = try c.decode(String.self, forKey: .teacher)
        let chineseTeacher = try? c.decode(String.self, forKey: .chineseTeacher)
        let day = try c.decode(String.self, forKey: .day)
        let time = try c.decode(String.self, forKey: .time)
        let grade = try c.decode(String.self, forKey: .grade)
        let room = try c.decode(String.self, forKey: .room)
        let buildingHint = try? c.decode(String.self, forKey: .buildingHint)

        // Prefer explicit id if present; otherwise compute a deterministic one
        if let parsed = try? c.decode(UUID.self, forKey: .id) {
            self.id = parsed
        } else {
            let key = [title, teacher, day, time, room].joined(separator: "|")
            self.id = stableUUID(from: key)
        }

        self.title = title
        self.teacher = teacher
        self.chineseTeacher = chineseTeacher
        self.day = day
        self.time = time
        self.grade = grade
        self.room = room
        self.buildingHint = buildingHint
    }
}


//```
//
//---
//
//// MARK: - File: Sources/Models/ClassDataProvider.swift
//```swift
import Foundation

public protocol ClassDataProvider {
    func load() -> [ClassItem]              // Load from cache/bundle for offline
    func refresh(completion: @escaping (Bool) -> Void) // Fetch newest data if possible
}

/// Google Sheets + Caching Provider
/// Set `sheetURL` to a JSON endpoint (e.g., https://opensheet.vercel.app/<SHEET_ID>/<TAB_NAME>)
public struct GoogleSheetsProvider: ClassDataProvider {
    private let sheetURL: URL?
    public init(sheetURL: URL? = nil) { self.sheetURL = sheetURL }

    public func load() -> [ClassItem] {
        if let override: [ClassItem] = Self.loadFromDocuments() { return override }
        if let bundled: [ClassItem] = Self.loadFromBundle() { return bundled }
        return []
    }

    public func refresh(completion: @escaping (Bool) -> Void) {
        guard let sheetURL else { completion(false); return }
        URLSession.shared.dataTask(with: sheetURL) { data, _, _ in
            guard let data else { completion(false); return }
            do {
                let items = try JSONDecoder().decode([ClassItem].self, from: data)
                guard !items.isEmpty else { completion(false); return }
                Self.saveToDocuments(data)
                UserDefaults.standard.set(Date(), forKey: "classes.lastUpdated")
                completion(true)
            } catch {
                completion(false)
            }
        }.resume()
    }
}

// MARK: Bundle/Disk helpers
private extension GoogleSheetsProvider {
    static func bundleURL() -> URL? {
        Bundle.main.url(forResource: "classes", withExtension: "json")
    }
    static func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("classes.json")
    }
    static func loadFromBundle() -> [ClassItem]? {
        guard let url = bundleURL(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ClassItem].self, from: data)
    }
    static func loadFromDocuments() -> [ClassItem]? {
        let url = documentsURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ClassItem].self, from: data)
    }
    static func saveToDocuments(_ data: Data) {
        let url = documentsURL()
        try? data.write(to: url, options: .atomic)
    }
}

/// Firebase placeholder – implement later and swap in via ClassStore(provider:)
public struct FirebaseProviderPlaceholder: ClassDataProvider {
    public init() {}
    public func load() -> [ClassItem] { [] }
    public func refresh(completion: @escaping (Bool) -> Void) { completion(false) }
}
//```
//
//---
//
//// MARK: - File: Sources/Store/ClassStore.swift
//```swift
import Foundation
import Combine

public final class ClassStore: ObservableObject {
    @Published public var query: String = ""
    @Published public var onlyOnSite: Bool = false
    @Published public private(set) var items: [ClassItem] = []
    @Published public var lastUpdated: Date? = UserDefaults.standard.object(forKey: "classes.lastUpdated") as? Date

    private let provider: ClassDataProvider

    public init(provider: ClassDataProvider) {
        self.provider = provider
        let first = provider.load()
        if first.isEmpty {
            // Safety fallback (ship a tiny built‑in set or leave empty)
            self.items = []
        } else {
            self.items = first
        }
    }

    public func reloadFromProvider() {
        self.items = provider.load()
        self.lastUpdated = UserDefaults.standard.object(forKey: "classes.lastUpdated") as? Date
    }

    public func refresh() {
        provider.refresh { success in
            DispatchQueue.main.async {
                if success { self.reloadFromProvider() }
            }
        }
    }

    public var filtered: [ClassItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            if onlyOnSite && item.room.lowercased().contains("online") { return false }
            guard !q.isEmpty else { return true }
            return [item.title, item.teacher, item.chineseTeacher ?? "", item.day, item.time, item.room, item.buildingHint ?? ""].joined(separator: " ")
                .lowercased().contains(q)
        }.sorted { $0.title < $1.title }
    }
}
//```
//
//---
//
//// MARK: - File: Sources/Views/ClassListView.swift
//```swift
import SwiftUI
import AuthenticationServices
// at file bottom or a new small file
struct MarkButton: View {
    @EnvironmentObject var schedule: ScheduleStore
    let item: ClassItem

    var body: some View {
        let isOn = schedule.isMarked(item.id)
        Button {
            schedule.toggle(item.id)
        } label: {
            Label(isOn ? "Unmark" : "Mark", systemImage: isOn ? "checkmark.circle.fill" : "plus.circle")
        }
        .tint(isOn ? .green : .blue)
    }
}
struct ClassListView: View {
    @EnvironmentObject var store: ClassStore

    var body: some View {
        NavigationStack {
            List(store.filtered) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        HStack { Image(systemName: "person"); Text(item.teacher) }
                            .font(.subheadline).foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            Label(item.day, systemImage: "calendar")
                            Label(item.time, systemImage: "clock")
                            Label(item.room, systemImage: "mappin.and.ellipse")
                        }.font(.caption)
                    }
                    
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {   // ⬅️ move it here
                        MarkButton(item: item)
                    }
            }
            .navigationDestination(for: ClassItem.self) { item in
                ClassDetailView(item: item)
            }
            .navigationTitle("Class Finder")
            .searchable(text: $store.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search class, teacher, room…")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { store.refresh() } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                    Toggle(isOn: $store.onlyOnSite) { Text("On‑site only") }
                    // Login/Profile
                        ProfileMenuButton()
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

#Preview {
    // Preview with in‑memory data
    let provider = GoogleSheetsProvider(sheetURL: nil)
    let store = ClassStore(provider: provider)
    store.query = ""
    return ClassListView().environmentObject(store)
}
//```
//
//---
//
//// MARK: - File: Sources/Views/ClassDetailView.swift
//```swift
import SwiftUI

struct ClassDetailView: View {
    let item: ClassItem
    @EnvironmentObject var schedule: ScheduleStore
    var body: some View {
        Form {
            Section(header: Text("Class")) {
                LabeledContent("Title", value: item.title)
                LabeledContent("Teacher", value: item.teacher)
                if let cn = item.chineseTeacher { LabeledContent("中文老师", value: cn) }
                LabeledContent("Grade", value: item.grade)
            }
            Section(header: Text("Schedule")) {
                LabeledContent("Day", value: item.day)
                LabeledContent("Time", value: item.time)
            }
            Section(header: Text("Location")) {
                LabeledContent("Room", value: item.room)
                LabeledContent("Building", value: item.buildingHint ?? "—")
            }
            if let building = item.buildingHint, building != "Gym" {
                Section {
                    NavigationLink("Open Building Map") { ZoomableImageView(imageName: "BuildingMap").navigationTitle("Building Map") }
                }
            }
        }
        .navigationTitle("Details")
        .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            schedule.toggle(item.id)
                        } label: {
                            Image(systemName: schedule.isMarked(item.id) ? "checkmark.circle.fill" : "plus.circle")
                        }
                        .accessibilityLabel(schedule.isMarked(item.id) ? "Unmark class" : "Mark class")
                    }
                }
    }
}

#Preview {
    ClassDetailView(item: .init(
        title: "四年级马立平 / MLP_G4",
        teacher: "Tianmin Lei",
        chineseTeacher: "雷天敏",
        day: "周日 on-site",
        time: "10:30-12:20PM",
        grade: "> 8岁",
        room: "C-4",
        buildingHint: "C"
    ))
}
//```
//
//---
//
//// MARK: - File: Sources/Views/ZoomableImageView.swift
//```swift
import SwiftUI

struct ZoomableImageView: View {
    let imageName: String
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { _ in
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(scale)
                .offset(offset)
                .background(Color(UIColor.systemBackground))
                .gesture(MagnificationGesture().onChanged { value in
                    scale = max(1.0, value)
                })
                .gesture(DragGesture()
                    .onChanged { value in
                        let t = value.translation
                        offset = CGSize(width: lastOffset.width + t.width, height: lastOffset.height + t.height)
                    }
                    .onEnded { _ in lastOffset = offset }
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Reset") { withAnimation { scale = 1.0; offset = .zero; lastOffset = .zero } }
                    }
                }
        }
    }
}

#Preview {
    NavigationStack { ZoomableImageView(imageName: "BuildingMap") }
}
//```
//
//---
//
//// MARK: - File: Sources/Views/SplashView.swift
//```swift
import SwiftUI

final class AppState: ObservableObject {
    @Published var isLoading = true
    let store: ClassStore

    init(store: ClassStore) { self.store = store }

    @MainActor
    func startup(sheetURL: URL?) async {
        // Attempt refresh (if URL provided). Continue regardless for offline.
        if let url = sheetURL {
            await withCheckedContinuation { continuation in
                store.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    continuation.resume()
                }
            }
        }
        isLoading = false
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image("LaunchLogo").resizable().scaledToFit().frame(width: 360, height:480)
                Text("Loading").font(.title3).bold()
                ProgressView().padding(.top, 6)
            }
        }
    }
}

#Preview { SplashView() }
//```
//
//---
//
//// MARK: - File: Sources/Views/RootTabs.swift
//```swift
import SwiftUI

struct RootTabs: View {
    var body: some View {
        let noticesURL = URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/notice")

        TabView {
            ClassListView()
                .tabItem { Label("Classes", systemImage: "list.bullet") }

            NavigationStack { ZoomableImageView(imageName: "BuildingMap").navigationTitle("Building Map") }
                .tabItem { Label("Buildings", systemImage: "map") }

            NavigationStack { ZoomableImageView(imageName: "ParkingMap").navigationTitle("Parking Map") }
                .tabItem { Label("Parking", systemImage: "car") }
            
            NoticeListView(sheetURL: noticesURL)
                            .tabItem { Label("Notices", systemImage: "bell") }
            
            MyScheduleView()
                            .tabItem { Label("My Schedule", systemImage: "calendar.badge.checkmark") }
                   
        }
    }
}

#Preview {
    let provider = GoogleSheetsProvider(sheetURL: nil)
    let store = ClassStore(provider: provider)
    return RootTabs().environmentObject(store)
}
//```
//
//---
// App/AppDelegate.swift (new)
import SwiftUI
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ app: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}
// MARK: - File: Sources/App/EdgemontClassFinderApp.swift
//```swift
import SwiftUI

@main
struct ClassFinderApp: App {
    // Set your Google Sheets JSON URL here (or leave nil for bundle/cache only)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let sheetURL = URL(string: "https://opensheet.vercel.app/1uuM1vd0U1YDiHCnB9M-40hZIltGE0ij3ELVOBcnjRog/test")

    // Swap provider when you move to Firebase: ClassStore(provider: FirebaseProvider(...))
    @StateObject private var store = ClassStore(provider: GoogleSheetsProvider(sheetURL: URL(string: "https://opensheet.vercel.app/1uuM1vd0U1YDiHCnB9M-40hZIltGE0ij3ELVOBcnjRog/test")))
    @StateObject private var authStore  = AuthStore()
    @StateObject private var appStateRef: AppState
    @StateObject private var schedule = ScheduleStore()

    init() {
        let provider = GoogleSheetsProvider(sheetURL: sheetURL)
        let store = ClassStore(provider: provider)
        _store = StateObject(wrappedValue: store)
        _appStateRef = StateObject(wrappedValue: AppState(store: store))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appStateRef.isLoading {
                    SplashView()
                        .task { await appStateRef.startup(sheetURL: sheetURL) }
                } else {
                    RootTabs()
                        .environmentObject(store)
                        .environmentObject(schedule)
                        .environmentObject(authStore)
                }
            }
        }
    }
}
//```
//
//---

//# Notes
//- Add `classes.json` to your bundle if you want a seed dataset for first launch.
//- Put your images (`BuildingMap`, `ParkingMap`, `LaunchLogo`) in **Assets.xcassets**.
//- To switch to Firebase later, implement a real `FirebaseProvider` conforming to `ClassDataProvider` and change the provider passed to `ClassStore` in `EdgemontClassFinderApp`.
