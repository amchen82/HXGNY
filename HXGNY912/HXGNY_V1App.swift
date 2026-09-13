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
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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

    public func refresh(completion: (() -> Void)? = nil) {
        provider.refresh { success in
            DispatchQueue.main.async {
                if success { self.reloadFromProvider() }
                completion?()
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
            .searchable(text: $store.query, prompt: "Search class, teacher, room…")
            .toolbar {
               
                ToolbarItem(placement: .automatic) {
                    Image("LaunchLogo") // 🎓 school icon
                        .resizable()
                                .scaledToFit()
//                                .frame(height: 24)  match SF Symbol height
//                                .padding(.leading, 4) // optional: adjust spacing
                }
                ToolbarItemGroup(placement: .automatic) {
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
            .onAppear {
                if store.items.isEmpty {
                    store.refresh()
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
                .background(Color.systemBackgroundCompat)
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
                    ToolbarItem(placement: .automatic) {
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
        if sheetURL != nil {
            await withCheckedContinuation { continuation in
                store.refresh {
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
            Color.systemBackgroundCompat.ignoresSafeArea()
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
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    homeHeader

                    VStack(spacing: 24) {
                        galleryFeature

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 14)], spacing: 14) {
                        homeFeatureCard(
                            title: "School\nIntro",
                            subtitle: "学校简介",
                            icon: "building.columns",
                            action: { activeSheet = .schoolIntro }
                        )

                        homeFeatureCard(
                            title: "Classes\n& rooms",
                            subtitle: "课程时间与教室 · \(classStore.items.count) classes",
                            icon: "clock",
                            action: { onNavigate(.classes) }
                        )
                        }

                        VStack(spacing: 0) {
                            homeRowCard(
                            title: "Weekly News",
                            subtitle: "校园新闻与通知",
                            detail: "Latest",
                            icon: "newspaper",
                            action: { activeSheet = .weeklynews }
                            )

                            Divider().padding(.leading, 78)

                            homeRowCard(
                            title: "School Calendar",
                            subtitle: "校历与停课安排",
                            detail: "View",
                            icon: "calendar",
                            action: { onNavigate(.calendar) }
                            )
                        }
                        .background(.white.opacity(colorScheme == .dark ? 0.08 : 0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )

                        moreSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 28)
                    .padding(.bottom, 34)
                }
                .frame(width: proxy.size.width, alignment: .top)
            }
            .scrollIndicators(.visible)
        }
        .background(HomeStyle.background.ignoresSafeArea())
            .sheet(item: $activeSheet) { which in
                NavigationStack {
                    switch which {
                    case .schoolIntro:
                        OneColumnListView(
                            title: "School Intro",
                            sheetURL: URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/schoolintro"),
                            slug: "join"
                        ).toolbar {
                            ToolbarItem(placement: .automatic) {
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
                            ToolbarItem(placement: .automatic) {
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
                            ToolbarItem(placement: .automatic) {
                                Button("< Back") {
                                    activeSheet = nil   // dismiss the sheet
                                }
                            }
                        }
                    case .sponsors:
                        Group {
                            if let sponsorsURL = URL(string: "https://opensheet.vercel.app/1S3rQnaCi_a3lAhOoVaVS_eGfgtMzh91kvRw0-BPKM_8/sheet1") {
                                SponsorAlbumView(sheetURL: sponsorsURL)
                            } else {
                                ContentUnavailableView("Sponsors Unavailable", systemImage: "photo")
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .automatic) {
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
                            ToolbarItem(placement: .automatic) {
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
                            ToolbarItem(placement: .automatic) {
                                Button("< Back") {
                                    activeSheet = nil   // dismiss the sheet
                                }
                            }
                        }
                    }
                }
            }
        }

    private var homeHeader: some View {
        VStack(spacing: 0) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 72)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Huaxia Chinese School of Greater New York")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(HomeStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)

                Text("200 White Oak Ln, Scarsdale NY · hxgny.org")
                .font(.subheadline)
                .foregroundStyle(HomeStyle.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(HomeStyle.headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var galleryFeature: some View {
        Button {
            onNavigate(.gallery)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("School Gallery")
                            .font(.system(size: 25, weight: .bold, design: .serif))
                            .foregroundStyle(HomeStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 10)

                        Text("View all")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HomeStyle.red)
                    }

                    Text("校园相册")
                        .font(.subheadline)
                        .foregroundStyle(HomeStyle.muted)
                }

                ZStack(alignment: .bottomLeading) {
                    HomeGalleryPreview()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.74)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("School moments")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        Text("Photos from school events")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.84))
                    }
                    .padding(20)
                }
                .frame(height: 216)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
            }
        }
        .buttonStyle(.plain)
    }

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MORE")
                .font(.caption.weight(.bold))
                .tracking(4)
                .foregroundStyle(HomeStyle.muted)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                homePill("Buildings", subtitle: "教学楼地图") { onNavigate(.buildings) }
                homePill("Campus Parking", subtitle: "校园停车") { onNavigate(.parking) }
                homePill("My Schedule", subtitle: "我的课程表") { onNavigate(.saved) }
                homePill("Sponsors", subtitle: "赞助商") { activeSheet = .sponsors }
                homePill("Lost & Found", subtitle: "失物招领") { activeSheet = .lostFound }
                homePill("Contact Office", subtitle: "联系办公室") { activeSheet = .contactus }
                homePill("Join Us", subtitle: "加入我们") { activeSheet = .joinus }
            }
        }
    }

    private func homeFeatureCard(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(HomeStyle.red)

                Spacer(minLength: 18)

                Text(title)
                    .font(.system(size: 23, weight: .bold, design: .serif))
                    .foregroundStyle(HomeStyle.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(HomeStyle.muted)
                    .lineLimit(1)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
            .background(HomeStyle.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func homeRowCard(title: String, subtitle: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(HomeStyle.red)
                    .frame(width: 54, height: 54)
                    .background(HomeStyle.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(HomeStyle.ink)
                        Spacer()
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(HomeStyle.muted)
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(HomeStyle.ink.opacity(0.78))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
    }

    private func homePill(_ title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HomeStyle.ink.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(HomeStyle.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(HomeStyle.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

private enum HomeStyle {
    static let background = LinearGradient(
        colors: [Color(hex: 0xF6F1E7), Color(hex: 0xECE5D8)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let headerBackground = LinearGradient(
        colors: [Color(hex: 0xFFF8EA), Color(hex: 0xF2E8D6)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let card = Color.white.opacity(0.9)
    static let placeholder = Color(hex: 0xD9D2C5)
    static let red = Color(hex: 0xB9251C)
    static let ink = Color(hex: 0x211D18)
    static let muted = Color(hex: 0x746B60)
}

// MARK: - Neutral palette (semantic, dark-mode aware)
private enum Palette {
    static let bg     = Color.systemBackgroundCompat
    static let card   = Color.secondarySystemBackgroundCompat
    static let iconBg = Color.tertiarySystemFillCompat
    static let stroke = Color.separatorCompat
    static let accent = Color.accentColor  // keep app’s global accent (blue by default)
    static let shadow = Color.black.opacity(0.08)
}



// Put this near HomeView.swift (replace your existing Brand)
import SwiftUI

private struct Brand {
    // Subtle, system-friendly neutrals
    static let stroke  = Color.separatorCompat
    static let shadow  = Color.black.opacity(0.04)   // lighter shadow
    static let cardBg  = Color.secondarySystemBackgroundCompat
    static let iconBg  = Color.tertiarySystemFillCompat
    static let textPri = Color.primary
    static let textSec = Color.secondary

    // Keep a single professional accent (or rely on app tint)
    static let accent  = Color.accentColor
}



// Small util for hex colors
private extension Color {
    static var systemBackgroundCompat: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var secondarySystemBackgroundCompat: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static var tertiarySystemFillCompat: Color {
        #if os(macOS)
        Color(nsColor: .quaternaryLabelColor)
        #else
        Color(uiColor: .tertiarySystemFill)
        #endif
    }

    static var separatorCompat: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }

    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


import SwiftUI

/// All full-screen destinations you can navigate to from Home
enum Route: Hashable {
    case classes, buildings, parking, calendar, gallery, saved
}

private enum GalleryConfiguration {
    static let folderID = "1yJqy9iZ3aXum5QBjlAeuXQVEq4s12f3H"
    static let apiKey = "AIzaSyDG2tp6s3EwJ527o6MDmpJJCBpqveEjk_Y"
    static let directPhotos = [
        DrivePhoto(
            id: "1ZByjZ-8pFM0gTzlxkAiDsGX58Rr88LQw",
            name: "Gallery Photo",
            thumbnailLink: nil
        )
    ]
}

private struct SponsorImage: Identifiable, Hashable {
    let id: String
    let url: URL
}

private struct SponsorAlbumView: View {
    let sheetURL: URL
    @State private var images: [SponsorImage] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedIndex = 0

    var body: some View {
        Group {
            if isLoading && images.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if images.isEmpty {
                ContentUnavailableView(
                    "No Sponsor Images",
                    systemImage: "photo",
                    description: Text(errorMessage ?? "Pull to refresh or check back later.")
                )
            } else {
                VStack(spacing: 14) {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                            SponsorImageCell(imageURL: image.url)
                                .padding(.horizontal, 16)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(maxWidth: .infinity)
                    .frame(height: 440)

                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 18)
                .refreshable {
                    await loadSponsors()
                }
            }
        }
        .navigationTitle("Sponsors")
        .task {
            await loadSponsors()
        }
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            advanceSponsor()
        }
        .onChange(of: images) { updatedImages in
            if selectedIndex >= updatedImages.count {
                selectedIndex = 0
            }
        }
    }

    private func loadSponsors() async {
        isLoading = true
        errorMessage = nil

        do {
            let (data, _) = try await URLSession.shared.data(from: sheetURL)
            let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            let urls = Self.imageURLs(from: rows)

            await MainActor.run {
                images = urls.map { SponsorImage(id: $0.absoluteString, url: $0) }
                isLoading = false
                if urls.isEmpty {
                    errorMessage = "The sponsor sheet has no PNG image links."
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Could not load sponsor images."
            }
        }
    }

    private static func imageURLs(from rows: [[String: Any]]) -> [URL] {
        var seen = Set<String>()
        var urls: [URL] = []

        for row in rows {
            let candidates = row.keys + row.values.map { String(describing: $0) }
            for candidate in candidates {
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard isImageURL(trimmed),
                      let url = URL(string: trimmed),
                      seen.insert(trimmed).inserted else {
                    continue
                }

                urls.append(url)
            }
        }

        return urls
    }

    private static func isImageURL(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased.hasPrefix("https://") &&
            (lowercased.contains(".png") || lowercased.contains(".jpg") || lowercased.contains(".jpeg"))
    }

    private func advanceSponsor() {
        guard images.count > 1 else { return }

        withAnimation(.easeInOut(duration: 0.45)) {
            selectedIndex = (selectedIndex + 1) % images.count
        }
    }
}

private struct SponsorImageCell: View {
    let imageURL: URL

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            @unknown default:
                EmptyView()
            }
        }
        .frame(height: 400)
        .frame(maxWidth: .infinity)
        .background(Color.secondarySystemBackgroundCompat)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct CalendarSheetRow: Identifiable, Hashable {
    let id = UUID()
    let date: String
    let status: String
    let activity: String
    let notes: String
}

private struct CalendarSheetView: View {
    let sheetURL: URL
    @State private var rows: [CalendarSheetRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                ContentUnavailableView(
                    "No Calendar Items",
                    systemImage: "calendar",
                    description: Text(errorMessage ?? "Pull to refresh or check back later.")
                )
            } else {
                List(rows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.date)
                                .font(.headline)
                            Spacer()
                            if !row.status.isEmpty {
                                Text(row.status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !row.activity.isEmpty {
                            Text(row.activity)
                                .font(.subheadline)
                        }

                        if !row.notes.isEmpty {
                            Text(row.notes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .refreshable {
                    await loadCalendar()
                }
            }
        }
        .task {
            await loadCalendar()
        }
    }

    private func loadCalendar() async {
        isLoading = true
        errorMessage = nil

        do {
            let (data, _) = try await URLSession.shared.data(from: sheetURL)
            let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            let parsed = objects.compactMap(Self.row(from:))

            await MainActor.run {
                rows = parsed
                isLoading = false
                if parsed.isEmpty {
                    errorMessage = "The calendar sheet is empty."
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Could not load the calendar."
            }
        }
    }

    private static func row(from object: [String: Any]) -> CalendarSheetRow? {
        let date = value("Date", in: object)
        let status = value("Week / Status", in: object)
        let activity = value("School Activity", in: object)
        let notes = value("Chinese / Notes", in: object)

        guard ![date, status, activity, notes].allSatisfy(\.isEmpty) else {
            return nil
        }

        return CalendarSheetRow(date: date, status: status, activity: activity, notes: notes)
    }

    private static func value(_ key: String, in object: [String: Any]) -> String {
        guard let actualKey = object.keys.first(where: { $0.caseInsensitiveCompare(key) == .orderedSame }),
              let value = object[actualKey] else {
            return ""
        }

        return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct DrivePhoto: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let thumbnailLink: String?

    var imageURL: URL? {
        if let thumbnailLink, let url = URL(string: thumbnailLink.replacingOccurrences(of: "=s220", with: "=s1200")) {
            return url
        }

        return URL(string: "https://drive.google.com/uc?export=view&id=\(id)")
    }
}

private struct DrivePhotoResponse: Decodable {
    let files: [DrivePhoto]
}

private struct DriveFolder: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
}

private struct DriveFolderResponse: Decodable {
    let files: [DriveFolder]
}

private struct DriveAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let photos: [DrivePhoto]
}

private struct HomeGalleryPreview: View {
    @State private var photos: [DrivePhoto] = []
    @State private var selectedIndex = 0
    @State private var zoomPreview = false

    var body: some View {
        ZStack {
            if let photo = photos[safe: selectedIndex] {
                AsyncImage(url: photo.imageURL) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .containerRelativeFrame(.horizontal) { length, _ in
                                length * 0.8
                            }
                            .containerRelativeFrame(.vertical) { length, _ in
                                length * 0.92
                            }
                            .background(HomeStyle.placeholder)
                            .scaleEffect(zoomPreview ? 1.18 : 1.0)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .task {
            await loadPreviewPhotos()
        }
        .onAppear {
            startPreviewZoom()
        }
        .onChange(of: selectedIndex) { _ in
            startPreviewZoom()
        }
        .onReceive(Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()) { _ in
            guard photos.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                selectedIndex = (selectedIndex + 1) % photos.count
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(HomeStyle.placeholder)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(HomeStyle.muted.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                )

            VStack(spacing: 10) {
                Image(systemName: "photo")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(HomeStyle.muted.opacity(0.9))
                Text("Campus photo albums")
                    .font(.headline)
                    .foregroundStyle(HomeStyle.ink.opacity(0.82))
            }
        }
    }

    private func startPreviewZoom() {
        zoomPreview = false
        withAnimation(.easeInOut(duration: 3.2)) {
            zoomPreview = true
        }
    }

    private func loadPreviewPhotos() async {
        guard !GalleryConfiguration.folderID.isEmpty, !GalleryConfiguration.apiKey.isEmpty else {
            photos = GalleryConfiguration.directPhotos
            return
        }

        do {
            let folders = try await loadFolders(in: GalleryConfiguration.folderID)
            var loadedPhotos: [DrivePhoto] = []

            for folder in folders {
                loadedPhotos.append(contentsOf: try await loadPhotos(in: folder.id))
            }

            if loadedPhotos.isEmpty {
                loadedPhotos = try await loadPhotos(in: GalleryConfiguration.folderID)
            }

            await MainActor.run {
                photos = loadedPhotos.isEmpty ? GalleryConfiguration.directPhotos : Array(loadedPhotos.prefix(12))
                selectedIndex = 0
            }
        } catch {
            await MainActor.run {
                photos = GalleryConfiguration.directPhotos
            }
        }
    }

    private func loadFolders(in parentID: String) async throws -> [DriveFolder] {
        let url = try makeDriveURL(
            query: "'\(parentID)' in parents and trashed = false and mimeType = 'application/vnd.google-apps.folder'",
            fields: "files(id,name)"
        )
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(DriveFolderResponse.self, from: data).files
    }

    private func loadPhotos(in parentID: String) async throws -> [DrivePhoto] {
        let url = try makeDriveURL(
            query: "'\(parentID)' in parents and trashed = false and mimeType contains 'image/'",
            fields: "files(id,name,thumbnailLink)"
        )
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(DrivePhotoResponse.self, from: data).files
    }

    private func makeDriveURL(query: String, fields: String) throws -> URL {
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: fields),
            URLQueryItem(name: "orderBy", value: "name"),
            URLQueryItem(name: "key", value: GalleryConfiguration.apiKey)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        return url
    }
}

private struct DriveGalleryView: View {
    let folderID: String
    let apiKey: String
    let directPhotos: [DrivePhoto]

    @State private var albums: [DriveAlbum] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && albums.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if albums.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo",
                    description: Text(errorMessage ?? "Pull to refresh or check back later.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        ForEach(albums) { album in
                            GalleryAlbumSection(album: album)
                        }
                    }
                    .padding(.vertical, 24)
                }
                .refreshable {
                    await loadPhotos()
                }
            }
        }
        .task {
            await loadPhotos()
        }
    }

    private func loadPhotos() async {
        guard !folderID.isEmpty, !apiKey.isEmpty else {
            albums = directPhotos.isEmpty ? [] : [
                DriveAlbum(id: "direct", title: "School Gallery", photos: directPhotos)
            ]
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let folders = try await loadFolders(in: folderID)
            var loadedAlbums: [DriveAlbum] = []

            for folder in folders {
                let photos = try await loadPhotos(in: folder.id)
                if !photos.isEmpty {
                    loadedAlbums.append(DriveAlbum(id: folder.id, title: folder.name, photos: photos))
                }
            }

            if loadedAlbums.isEmpty {
                let rootPhotos = try await loadPhotos(in: folderID)
                if !rootPhotos.isEmpty {
                    loadedAlbums = [DriveAlbum(id: folderID, title: "School Gallery", photos: rootPhotos)]
                }
            }

            if loadedAlbums.isEmpty && !directPhotos.isEmpty {
                loadedAlbums = [DriveAlbum(id: "direct", title: "School Gallery", photos: directPhotos)]
            }

            await MainActor.run {
                albums = loadedAlbums
                isLoading = false
                if loadedAlbums.isEmpty {
                    errorMessage = "The Drive folder has no public image files."
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Could not load gallery photos."
            }
        }
    }

    private func loadFolders(in parentID: String) async throws -> [DriveFolder] {
        let url = try makeDriveURL(
            query: "'\(parentID)' in parents and trashed = false and mimeType = 'application/vnd.google-apps.folder'",
            fields: "files(id,name)"
        )
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(DriveFolderResponse.self, from: data).files
    }

    private func loadPhotos(in parentID: String) async throws -> [DrivePhoto] {
        let url = try makeDriveURL(
            query: "'\(parentID)' in parents and trashed = false and mimeType contains 'image/'",
            fields: "files(id,name,thumbnailLink)"
        )
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(DrivePhotoResponse.self, from: data).files
    }

    private func makeDriveURL(query: String, fields: String) throws -> URL {
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: fields),
            URLQueryItem(name: "orderBy", value: "name"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        return url
    }
}

private struct GalleryAlbumSection: View {
    let album: DriveAlbum
    @State private var selectedIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(album.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text("\(album.photos.count) photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("View all")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 18)

            TabView(selection: $selectedIndex) {
                ForEach(Array(album.photos.enumerated()), id: \.element.id) { index, photo in
                    GalleryPhotoCell(photo: photo)
                        .padding(.horizontal, 18)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 250)
        }
        .onReceive(Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()) { _ in
            advancePhoto()
        }
        .onChange(of: album.photos) { updatedPhotos in
            if selectedIndex >= updatedPhotos.count {
                selectedIndex = 0
            }
        }
    }

    private func advancePhoto() {
        guard album.photos.count > 1 else { return }

        withAnimation(.easeInOut(duration: 0.45)) {
            selectedIndex = (selectedIndex + 1) % album.photos.count
        }
    }
}

private struct GalleryPhotoCell: View {
    let photo: DrivePhoto

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: photo.imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()

            Text(photo.name)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .background(Color.secondarySystemBackgroundCompat)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 8)
    }
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
                    if let calendarURL = URL(string: "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/calendar") {
                        CalendarSheetView(sheetURL: calendarURL)
                            .navigationTitle("Calendar")
                    } else {
                        ContentUnavailableView("Calendar Unavailable", systemImage: "calendar")
                    }
                case .gallery:
                    DriveGalleryView(
                        folderID: GalleryConfiguration.folderID,
                        apiKey: GalleryConfiguration.apiKey,
                        directPhotos: GalleryConfiguration.directPhotos
                    )
                        .navigationTitle("Gallery")
                case .saved:
                    MyScheduleView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    UpdateButton()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
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
        .font(.caption.weight(.semibold))
        .foregroundColor(.blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
        .accessibilityLabel("Install update from App Store")
    }
}
