//
//  ScheduleViewerApp.swift
//  ScheduleViewer
//
//  Created by mark on 7/12/25.
//  Updated to match Provider Schedule Calendar's exact architecture
//

import SwiftUI
import CloudKit

@main
struct ScheduleViewerApp: App {
    @StateObject private var cloudKitManager = CloudKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if let url = userActivity.webpageURL {
                        handleIncomingURL(url)
                    }
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("🔗 SV APP: Received URL: \(url.absoluteString)")
        
        if url.absoluteString.contains("icloud.com/share/") {
            print("🔗 SV APP: Detected CloudKit share URL, attempting acceptance")
            cloudKitManager.acceptShareFromURL(url) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ SV APP: Share accepted successfully via URL")
                    } else {
                        print("❌ SV APP: Share acceptance failed via URL: \(error?.localizedDescription ?? "unknown")")
                    }
                }
            }
        } else {
            print("🔗 SV APP: URL is not a CloudKit share URL")
        }
    }
}