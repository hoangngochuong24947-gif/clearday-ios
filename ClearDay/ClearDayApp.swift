//
//  ClearDayApp.swift
//  ClearDay
//
//  Created by 卢柳源 on 2026/7/10.
//

import SwiftData
import SwiftUI

@main
struct ClearDayApp: App {
    private let modelContainer = AppDatabase.shared.container

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
