//
//  ScheduleViewerApp.swift
//  ScheduleViewer
//
//  Created by mark on 7/12/25.
//

import SwiftUI

@main
struct ScheduleViewerApp: App {
    let cloudKitManager = CloudKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
        }
    }
}
