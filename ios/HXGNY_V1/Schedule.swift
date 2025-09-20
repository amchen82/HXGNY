//
//  Schedule.swift
//  HXGNYV1
//
//  Created by Chen Feng on 9/9/25.
//

import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
public final class ScheduleStore: ObservableObject {
    @Published public private(set) var marked: Set<UUID> = []
    private let localKey = "schedule.ids"

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    public init() {
        loadLocal()
        // If FirebaseAuth is present, listen for user changes to sync
        #if canImport(FirebaseAuth)
        Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { await self?.syncFromCloudIfAvailable() }
        }
        #endif
    }

    // MARK: - Public API
    public func isMarked(_ id: UUID) -> Bool { marked.contains(id) }

    public func toggle(_ id: UUID) {
        if marked.contains(id) { marked.remove(id) } else { marked.insert(id) }
        saveLocal()
        Task { await saveToCloudIfAvailable() }
    }

    // MARK: - Local persistence
    private func loadLocal() {
        guard let data = UserDefaults.standard.array(forKey: localKey) as? [String] else { return }
        self.marked = Set(data.compactMap(UUID.init(uuidString:)))
    }

    private func saveLocal() {
        let strings = marked.map(\.uuidString)
        UserDefaults.standard.set(strings, forKey: localKey)
    }

    // MARK: - Cloud sync (optional; no-ops if Firebase not linked)
    private func userUID() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    public func syncFromCloudIfAvailable() async {
        guard let uid = userUID() else { return }
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("users").document(uid).collection("meta").document("schedule")
            let snap = try await ref.getDocument()
            if let ids = snap.data()?["ids"] as? [String] {
                // Merge: union remote+local, then push back up
                let remote = Set(ids.compactMap(UUID.init(uuidString:)))
                let union = self.marked.union(remote)
                if union != self.marked {
                    self.marked = union
                    saveLocal()
                    try await ref.setData(["ids": union.map(\.uuidString)], merge: true)
                }
            }
        } catch { /* ignore for offline */ }
        #endif
    }

    public func saveToCloudIfAvailable() async {
        guard let uid = userUID() else { return }
        #if canImport(FirebaseFirestore)
        do {
            let ref = db.collection("users").document(uid).collection("meta").document("schedule")
            try await ref.setData(["ids": self.marked.map(\.uuidString)], merge: true)
        } catch { /* ignore for offline */ }
        #endif
    }
    
    public func clear() {
            marked.removeAll()
            UserDefaults.standard.removeObject(forKey: localKey)
        }
}


import SwiftUI

struct MyScheduleView: View {
    @EnvironmentObject var store: ClassStore
    @EnvironmentObject var schedule: ScheduleStore

    var myItems: [ClassItem] {
        let set = schedule.marked
        return store.items.filter { set.contains($0.id) }
            .sorted { ($0.time, $0.title) < ($1.time, $1.title) }
    }

    var body: some View {
        NavigationStack {
            if myItems.isEmpty {
                ContentUnavailableView("No classes marked",
                                       systemImage: "calendar.badge.plus",
                                       description: Text("Mark classes from the list or details to build your schedule."))
                    .navigationTitle("My Schedule")
            } else {
                List(myItems) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            HStack(spacing: 12) {
                                Label(item.day, systemImage: "calendar")
                                Label(item.time, systemImage: "clock")
                                Label(item.room, systemImage: "mappin.and.ellipse")
                            }.font(.caption)
                        }
                    }
                    .swipeActions {
                        MarkButton(item: item) // allows quick unmark
                    }
                }
                .navigationDestination(for: ClassItem.self) { ClassDetailView(item: $0) }
                .navigationTitle("My Schedule")
            }
        }
    }
}

#Preview {
    // minimal preview (no schedule data)
    let provider = GoogleSheetsProvider(sheetURL: nil)
    let store = ClassStore(provider: provider)
    let schedule = ScheduleStore()
    return MyScheduleView()
        .environmentObject(store)
        .environmentObject(schedule)
}
