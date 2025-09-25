//
//  MyScheduleStore.swift
//  HXGNYV1
//
//  Created by Chen Feng on 9/12/25.
//

import Foundation
import SwiftUI

public final class MyScheduleStore: ObservableObject {
    @Published public private(set) var saved: [ClassItem] = []

    private let saveKey = "MySavedClasses"

    public init() {
        load()
    }

    public func toggle(_ item: ClassItem) {
        if saved.contains(item) {
            saved.removeAll { $0.id == item.id }
        } else {
            saved.append(item)
        }
        save()
    }

    public func isSaved(_ item: ClassItem) -> Bool {
        saved.contains(item)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([ClassItem].self, from: data) {

            // Keep only unique items by id, preserving order
            var seen = Set<UUID>()
            self.saved = decoded.filter { item in
                if seen.contains(item.id) {
                    return false
                } else {
                    seen.insert(item.id)
                    return true
                }
            }
        }
    }

    private func save() {
        let unique = Array(
            Dictionary(grouping: saved, by: { $0.id }).compactMap { $0.value.first }
        )
        if let data = try? JSONEncoder().encode(unique) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
}

