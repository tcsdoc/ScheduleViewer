//
//  ScheduleViewerApp.swift
//  ScheduleViewer
//
//  Created by mark on 7/12/25.
//

import SwiftUI
import CloudKit

@main
struct ScheduleViewerApp: App {
    let cloudKitManager = CloudKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
                .onOpenURL { url in
                    print("🔗 ScheduleViewer opened with URL: \(url)")
                    
                    // Check if this is a CloudKit share URL
                    if url.host == "www.icloud.com" && url.path.contains("/share/") {
                        print("✅ Detected CloudKit share URL - attempting to accept")
                        cloudKitManager.acceptShare(from: url)
                    } else {
                        print("ℹ️ Non-CloudKit URL received: \(url)")
                    }
                }
        }
    }
}
