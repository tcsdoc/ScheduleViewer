//
//  ScheduleViewerApp.swift
//  ScheduleViewer
//
//  Created by mark on 7/12/25.
//  Updated to match Provider Schedule Calendar's exact architecture
//

import SwiftUI

@main
struct ScheduleViewerApp: App {
    @StateObject private var cloudKitManager = CloudKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
                .onOpenURL { url in
                    if url.absoluteString.contains("icloud.com/share/") {
                        cloudKitManager.acceptShareFromURL(url) { success, error in
                            // Handle result if needed
                        }
                    }
                }
        }
    }
}