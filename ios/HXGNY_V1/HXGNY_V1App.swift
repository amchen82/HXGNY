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
    public let category: String

    public init(
        id: UUID = UUID(),
        title: String,
        teacher: String,
        chineseTeacher: String?,
        day: String,
        time: String,
        grade: String,
        room: String,
        buildingHint: String?,
        category: String
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
        self.category = category
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()  // default if missing
        self.title = try c.decode(String.self, forKey: .title)
        self.teacher = try c.decode(String.self, forKey: .teacher)
        self.chineseTeacher = try? c.decode(String.self, forKey: .chineseTeacher)
        self.day = try c.decode(String.self, forKey: .day)
        self.time = try c.decode(String.self, forKey: .time)
        self.grade = try c.decode(String.self, forKey: .grade)
        self.room = try c.decode(String.self, forKey: .room)
        self.buildingHint = try? c.decode(String.self, forKey: .buildingHint)
        self.category = try c.decode(String.self, forKey: .category) // ← decode safely
        
    }
    
    
}
public extension ClassItem {
    /// Estimate the minimum age required for the class
    var minAge: Int? {
        let g = grade.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Direct age in years (e.g., "> 6岁", "7岁")
        if let match = g.range(of: "[0-9]{1,2}(?=岁)", options: .regularExpression) {
            return Int(g[match])
        }

        // PreK / Kindergarten → age 4–5
        if g.contains("prek") || g.contains("pre-k") { return 4 }
        if g.contains("k") && !g.contains("1st") { return 5 }

        // 1st–12th grade mappings
        let gradeMap: [String: Int] = [
            "1st": 6, "2nd": 7, "3rd": 8, "4th": 9,
            "5th": 10, "6th": 11, "7th": 12,
            "8th": 13, "9th": 14, "10th": 15,
            "11th": 16, "12th": 17
        ]

        for (keyword, age) in gradeMap {
            if g.contains(keyword) { return age }
        }

        // "& up" — try to pull grade before "&"
        if g.contains("& up") {
            for (keyword, age) in gradeMap {
                if g.contains(keyword) { return age }
            }
        }

        // Adults: assume 18+
        if g.contains("adult") { return 18 }

        return nil
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
    
    public var categories: [String] {
        let set = Set(items.map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) })
        return set.sorted()
    }
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

    public func filtered(matching category: String) -> [ClassItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Normalize a helper for case-insensitive compare
        func norm(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        return items.filter { item in
            // On-site only
            if onlyOnSite {
                let isOnline = norm(item.room).contains("online") || norm(item.room).contains("zoom")
                if isOnline { return false }
            }

            // Category filter (use contains to forgive pluralization / minor variations)
            if !category.isEmpty {
                if !norm(item.category).contains(norm(category)) { return false }
            }

            // Numeric age query (exact)
            if let age = Int(q) {
                guard let min = item.minAge else { return false }
                return min == age
            }

            // Text query
            guard !q.isEmpty else { return true }
            return [item.title, item.teacher, item.chineseTeacher ?? "", item.day, item.time, item.grade, item.room, item.category, item.buildingHint ?? ""]
                .joined(separator: " ")
                .lowercased()
                .contains(q)
        }
        .sorted { $0.title < $1.title }
    }
}


import SwiftUI

struct MyScheduleView: View {
    @EnvironmentObject var schedule: MyScheduleStore

    var body: some View {
        Group {
            if schedule.saved.isEmpty {
                ContentUnavailableView("No Saved Classes", systemImage: "bookmark", description: Text("Swipe left on a class to save it."))
            } else {
                List(schedule.saved) { item in
                    VStack(alignment: .leading) {
                        Text(item.title).font(.headline)
                        HStack {
                                    Text("\(item.time)")
                                    
                                    Spacer()
                                    Text("\(item.day)")
                                    Spacer()
                                    Text(item.room)
                                }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }.swipeActions {
                        Button(role: .destructive) {
                            schedule.toggle(item)   // removes if already saved
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle("My Schedule")
            }
        }
    }
}


//```
//
//---
//
//// MARK: - File: Sources/Views/ClassListView.swift
//```swift
import SwiftUI

struct ClassListView: View {
    @EnvironmentObject var store: ClassStore
    @State private var selectedCategory: String = ""
    @EnvironmentObject var schedule: MyScheduleStore
    let predefinedCategories = [
        "", // ← For "All" / default
        "Junior Chinese Language Classes",
        "Senior Chinese Language Class",
        "Junior Enrichment Class",
        "Senior Enrichment Class",
        "Adult Classes"
    ]
    var body: some View {
       
            // Category Picker
            Picker("Category", selection: $selectedCategory) {
                                Text("All Categories").tag("")
                ForEach(store.categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.horizontal)
            
            List {
                ForEach(store.filtered(matching: selectedCategory)) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            HStack {
                                Image(systemName: "graduationcap.fill")
                                Text(item.grade)
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                Label(item.day, systemImage: "calendar")
                                Label(item.time, systemImage: "clock")
                                Label(item.room, systemImage: "mappin.and.ellipse")
                            }
                            .font(.caption)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            schedule.toggle(item)
                        } label: {
                            Label(schedule.isSaved(item) ? "Remove" : "Save", systemImage: schedule.isSaved(item) ? "bookmark.slash" : "bookmark")
                        }
                        .tint(schedule.isSaved(item) ? .red : .blue)
                    }
                }
            }
            .navigationTitle("Classes")
            .searchable(text: $store.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search class, teacher, room…")
            .toolbar {
               
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("LaunchLogo") // 🎓 school icon
                        .resizable()
                                .scaledToFit()
//                                .frame(height: 24)  match SF Symbol height
//                                .padding(.leading, 4) // optional: adjust spacing
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { store.refresh() } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                    Toggle(isOn: $store.onlyOnSite) { Text("On‑site only") }
                    
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

    var body: some View {
        Form {
            Section(header: Text("Class")) {
                LabeledContent("Title", value: item.title)
                LabeledContent("Teacher", value: item.teacher)
                if let cn = item.chineseTeacher { LabeledContent("中文老师", value: cn) }
                LabeledContent("Grade", value: item.grade)
                LabeledContent("Category", value: item.category)
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
        buildingHint: "C",
        category:"Junior Chinese Language Classes"
    ))
}
//```
//
//---
//
//// MARK: - File: Sources/Views/ZoomableImageView.swift
//```swift
import SwiftUI

import SwiftUI

struct ZoomableImageView: View {
    let imageName: String
    var minScale: CGFloat = 1.0
    var maxScale: CGFloat = 6.0

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))
                .scaleEffect(scale)
                .offset(offset)
                // Pinch to zoom
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            // Clamp scale
                            scale = max(minScale, min(maxScale, value))
                        }
                )
                // Drag to pan
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let t = value.translation
                            offset = CGSize(
                                width: lastOffset.width + t.width,
                                height: lastOffset.height + t.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                // Double-tap to zoom in/out
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale < 2.0 {
                            scale = 2.0
                        } else {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
                .contentShape(Rectangle()) // improves gesture hit-testing
        }
    }
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

import SwiftUI



// MARK: - File: Sources/App/EdgemontClassFinderApp.swift
//```swift
import SwiftUI

@main
struct EdgemontClassFinderApp: App {
    // Set your Google Sheets JSON URL here (or leave nil for bundle/cache only)
    private let sheetURL = URL(string: "https://opensheet.vercel.app/1uuM1vd0U1YDiHCnB9M-40hZIltGE0ij3ELVOBcnjRog/test")

    // Swap provider when you move to Firebase: ClassStore(provider: FirebaseProvider(...))
    @StateObject private var store = ClassStore(provider: GoogleSheetsProvider(sheetURL: URL(string: "https://opensheet.vercel.app/1uuM1vd0U1YDiHCnB9M-40hZIltGE0ij3ELVOBcnjRog/test")))
    @StateObject private var appStateRef: AppState
    @StateObject private var schedule = MyScheduleStore()

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
                    AppRoot()
                        .environmentObject(store)
                        .environmentObject((schedule))
                }
            }
        }
    }
}





import SwiftUI

struct HomeView: View {
    // instead of @Binding var selectedTab: RootTabs.Tab
    let onNavigate: (Route) -> Void

    @EnvironmentObject var classStore: ClassStore
    @EnvironmentObject var schedule: MyScheduleStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeSheet: Sheet?
    enum Sheet: Identifiable, Hashable { case joinus,  lostFound, sponsors,weeklynews,schoolIntro, contactus; var id: Self { self } }

    var body: some View {
       
            ScrollView {
                VStack(spacing: 4) {
                    
                    // App logo as title
                                    Image("LaunchLogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 80)   // adjust size
                                        .padding(.top, 12)
                    VStack(spacing: 4) {
                        Text("Huaxia Chinese School of Greater New York")
                            .font(.subheadline).fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("200 White Oak Ln, Scarsdale, NY 10583")
                            .font(.caption).fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // tappable email
                        HStack(spacing: 6) {
                            // Website
                            HStack(spacing: 3) {
                                Image(systemName: "globe")
                                    .imageScale(.small)
                                    .foregroundStyle(.secondary)
                                Link("www.hxgny.org",
                                     destination: URL(string: "https://www.hxgny.org")!)
                            }
                            // Email
                            HStack(spacing: 3) {
                                Image(systemName: "envelope")
                                    .imageScale(.small)
                                    .foregroundStyle(.secondary)
                                Link("hxgnyadmin@googlegroups.com",
                                     destination: URL(string: "mailto:hxgnyadmin@googlegroups.com")!)
                            }
                            
                            
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }
                    
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                  
                    featureCard(
                        title: "School Intro",
                        subtitle: "学校简介",
                        icon: "list.bullet.rectangle",
//                        gradient: Brand.blue,
                        action: { activeSheet = .schoolIntro}
                    )
                    
                    featureCard(
                        title: "Classes",
                        subtitle: "\(classStore.items.count) 课程信息",
                        icon: "list.bullet.rectangle",
//                        gradient: Brand.blue,
                        action: { onNavigate(.classes) }
                    )

                    featureCard(
                        title: "Buildings",
                        subtitle: "校园地图",
                        icon: "map",
//                        gradient: Brand.teal,
                        action: { onNavigate(.buildings) }
                    )

                    featureCard(
                        title: "Parking",
                        subtitle: "停车地图",
                        icon: "car",
//                        gradient: Brand.slate,
                        action: { onNavigate(.parking) }
                    )

                    featureCard(
                        title: "Weekly News",
                        subtitle: "校园周报",
                        icon: "bell",
//                        gradient: Brand.orange,
                        action: { activeSheet = .weeklynews }
                    )

                    featureCard(
                        title: "School Calendar",
                        subtitle: "校历",
                        icon: "calendar",
//                        gradient: Brand.purple,
                        action: { onNavigate(.calendar) }
                    )

                    featureCard(
                        title: "My Schedule",
                        subtitle: "\(schedule.saved.count) 关注的课程",
                        icon: "bookmark",
//                        gradient: Brand.pink,
                        action: { onNavigate(.saved) }
                    )

                    // Sheets from Home
//                    featureCard(
//                        title: "Upcoming Events",
//                        subtitle: "活动预告",
//                        icon: "star",
//                        gradient: Brand.gold,
//                        action: { activeSheet = .events }
//                    )
                    featureCard(
                        title: "Lost & Found",
                        subtitle: "失物招领",
                        icon: "questionmark.folder",
//                        gradient: Brand.slate,
                        action: { activeSheet = .lostFound }
                    )
                    
                    featureCard(
                        title: "Sponsors",
                        subtitle: "赞助",
                        icon: "hands.sparkles",
//                        gradient: Brand.orange,
                        action: { activeSheet = .sponsors }
                    )
                    featureCard(
                        title: "Contact Us",
                        subtitle: "联系我们",
                        icon: "envelope",
//                        gradient: Brand.teal,
                        action: { activeSheet = .contactus }
                    )
                    featureCard(
                        title: "Join Us",
                        subtitle: "加入我们",
                        icon: "envelope",
//                        gradient: Brand.teal,
                        action: { activeSheet = .joinus }
                    )
                }
                .padding(16)
            }
            .background(Palette.bg.ignoresSafeArea())
            .sheet(item: $activeSheet) { which in
                NavigationStack {
                    switch which {
                    case .schoolIntro:
                        OneColumnListView(
                            title: "School Intro",
                            sheetURL: URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/schoolintro"),
                            slug: "join"
                        ).toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("< Back") {
                                    activeSheet = nil   // dismiss the sheet
                                }
                            }
                        }
                    case .joinus:
                        OneColumnListView(
                            title: "Join Us",
                            sheetURL: URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/joinus"),
                            slug: "join"
                        ).toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("< Back") {
                                    activeSheet = nil   // dismiss the sheet
                                }
                            }
                        }
                    case .lostFound:
                        OneColumnListView(
                            title: "Lost & Found",
                            sheetURL: URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/lostnFound"),
                            slug: "lostfound"
                        )
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("< Back") {
                                    activeSheet = nil   // dismiss the sheet
                                }
                            }
                        }
                    case .sponsors:
                        OneColumnListView(
                            title: "Sponsors",
                            sheetURL: URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/sponsors"),
                            slug: "sponsors"
                        )
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("< Back") {
                                    activeSheet = nil   // dismiss the sheet
                                }
                            }
                        }
                    case .contactus:
                        OneColumnListView(
                            title: "Contact Us",
                            sheetURL: URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/contact"),
                            slug: "contact"
                        )
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("< Back") {
                                    activeSheet = nil   // dismiss the sheet
                                }
                            }
                        }
                        
                    case .weeklynews :
                        OneColumnListView(
                            title: "Weekly News",
                            sheetURL: URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/notice"),
                            slug: "weeklynews")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("< Back") {
                                    activeSheet = nil   // dismiss the sheet
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // your existing featureCard(...) helper remains unchanged

    @ViewBuilder
    private func featureCard(
        title: String,
        subtitle: String,
        icon: String,
        iconTint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .padding(10)
                    .background(.thinMaterial, in: Circle()) // 👈 icon also gets material

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(.thinMaterial)   // 👈 main card background
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(subtitle)")
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Neutral palette (semantic, dark-mode aware)
private enum Palette {
    static let bg     = Color(uiColor: .systemBackground)
    static let card   = Color(uiColor: .secondarySystemBackground)
    static let iconBg = Color(uiColor: .tertiarySystemFill)
    static let stroke = Color(uiColor: .separator)
    static let accent = Color.accentColor  // keep app’s global accent (blue by default)
    static let shadow = Color.black.opacity(0.08)
}



// Put this near HomeView.swift (replace your existing Brand)
import SwiftUI

private struct Brand {
    // Subtle, system-friendly neutrals
    static let stroke  = Color(uiColor: .separator)
    static let shadow  = Color.black.opacity(0.04)   // lighter shadow
    static let cardBg  = Color(uiColor: .secondarySystemBackground)
    static let iconBg  = Color(uiColor: .tertiarySystemFill)
    static let textPri = Color.primary
    static let textSec = Color.secondary

    // Keep a single professional accent (or rely on app tint)
    static let accent  = Color.accentColor
}



// Small util for hex colors
private extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}


import SwiftUI

/// All full-screen destinations you can navigate to from Home
enum Route: Hashable {
    case classes, buildings, parking,  calendar, saved
}

struct AppRoot: View {
    @EnvironmentObject var store: ClassStore
    @EnvironmentObject var schedule: MyScheduleStore
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            // Home is now the only root screen
            HomeView(onNavigate: { route in
                path.append(route)
            })
            .navigationBarTitleDisplayMode(.large)
            
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .classes:
                    ClassListView()
                case .buildings:
                    ZoomableImageView(imageName: "BuildingMap")
                        .navigationTitle("Building Map")
                case .parking:
                    ZoomableImageView(imageName: "ParkingMap")
                        .navigationTitle("Parking Map")
            
                case .calendar:
                    ZoomableImageView(imageName: "HXGNY-Calendar")
                            .navigationTitle("Calendar")
                case .saved:
                    MyScheduleView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                            UpdateButton()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.ultraThinMaterial)   // subtle background
                        }
        }
    }
}

#Preview {
    let provider = GoogleSheetsProvider(sheetURL: nil)
    let store = ClassStore(provider: provider)
    let schedule = MyScheduleStore()
    return AppRoot()
        .environmentObject(store)
        .environmentObject(schedule)
}


import SwiftUI

/// Update helper – set your real App Store ID below.
enum AppUpdater {
    /// Replace with your real App Store numeric ID (no "id" prefix).
    static let appID = "6752210002"

    static var appStoreURL: URL {
        URL(string: "itms-apps://itunes.apple.com/app/id\(appID)")!
    }

    static var webFallbackURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appID)")!
    }
}

struct UpdateButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Install Update") {
            openURL(AppUpdater.appStoreURL)
        }
        .font(.subheadline)          // keep it small in nav bar
        .foregroundColor(.blue)      // match system link color
        .accessibilityLabel("Install update from App Store")
    }
}


