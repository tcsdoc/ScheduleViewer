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
                    debugLog("📬 ScheduleViewer received URL: \(url)")
                    if url.absoluteString.contains("icloud.com/share/") {
                        debugLog("🔗 CloudKit share URL detected, accepting share...")
                        cloudKitManager.acceptShareFromURL(url) { success, error in
                            if success {
                                debugLog("✅ Share accepted successfully")
                            } else {
                                debugLog("❌ Failed to accept share: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    }
                }
        }
    }
}