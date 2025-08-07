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
                    #if DEBUG
                    print("🔗 ScheduleViewer opened with URL: \(url)")
                    #endif
                    
                    // Check if this is a CloudKit share URL
                    if url.host == "www.icloud.com" && url.path.contains("/share/") {
                        #if DEBUG
                        print("✅ Detected CloudKit share URL - attempting to accept")
                        #endif
                        cloudKitManager.acceptShare(from: url)
                    } else {
                        #if DEBUG
                        print("ℹ️ Non-CloudKit URL received")
                        #endif
                    }
                }
        }
    }
}
