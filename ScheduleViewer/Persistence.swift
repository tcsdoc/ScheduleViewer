//
//  Persistence.swift
//  ScheduleViewer
//
//  Created by mark on 7/5/25.
//  Updated for Core Data + CloudKit Private Database integration
//

import Foundation
import CloudKit

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    @Published var dailySchedules: [DailyScheduleRecord] = []
    @Published var monthlyNotes: [MonthlyNotesRecord] = []
    @Published var isLoading = false
    
    init() {
        container = CKContainer(identifier: "iCloud.com.gulfcoast.ProviderCalendar")
        privateDatabase = container.privateCloudDatabase
        
        // Listen for CloudKit share acceptance notifications
        setupShareNotifications()
    }
    
    /// Setup notifications to handle CloudKit share acceptance
    private func setupShareNotifications() {
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 CloudKit account changed - checking for new shares")
            self.fetchAllData()
        }
    }
    
    func fetchAllData() {
        isLoading = true
        
        // Check CloudKit account status first
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    print("✅ CloudKit account available in ScheduleViewer")
                case .noAccount:
                    print("❌ No iCloud account in ScheduleViewer")
                case .restricted:
                    print("❌ iCloud restricted in ScheduleViewer")
                case .couldNotDetermine:
                    print("❌ Could not determine iCloud status in ScheduleViewer")
                case .temporarilyUnavailable:
                    print("⚠️ iCloud temporarily unavailable in ScheduleViewer")
                @unknown default:
                    print("❓ Unknown iCloud status in ScheduleViewer")
                }
            }
        }
        
        let group = DispatchGroup()
        
        // Fetch Daily Schedules
        group.enter()
        fetchDailySchedules {
            group.leave()
        }
        
        // Fetch Monthly Notes
        group.enter()
        fetchMonthlyNotes {
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("🏁 ScheduleViewer: Data fetch completed")
            self.isLoading = false
        }
    }
    
    private func fetchDailySchedules(completion: @escaping () -> Void) {
        let query = CKQuery(recordType: "CD_DailySchedule", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
        
        Task {
            var allScheduleRecords: [DailyScheduleRecord] = []
            
            // Fetch from private database zones
            do {
                let privateZones = try await privateDatabase.allRecordZones()
                print("🔍 Fetching daily schedules from \(privateZones.count) private zones...")
                
                for zone in privateZones {
                    print("   Checking private zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                    
                    do {
                        let (records, _) = try await privateDatabase.records(matching: query, inZoneWith: zone.zoneID)
                        let scheduleRecords = records.compactMap { _, result in
                            try? result.get()
                        }.compactMap { record in
                            DailyScheduleRecord(from: record)
                        }
                        
                        print("   ✅ Found \(scheduleRecords.count) daily schedules in private zone \(zone.zoneID.zoneName)")
                        allScheduleRecords.append(contentsOf: scheduleRecords)
                        
                        // Log some sample records for debugging
                        for schedule in scheduleRecords.prefix(3) {
                            let dateStr = schedule.date?.description ?? "No date"
                            let line1 = schedule.line1 ?? ""
                            print("     📅 Private Schedule: \(dateStr) - \(line1)")
                        }
                        
                    } catch {
                        print("   ❌ Error fetching from private zone \(zone.zoneID.zoneName): \(error)")
                    }
                }
                
                // Also fetch from shared database zones
                let sharedDatabase = container.sharedCloudDatabase
                let sharedZones = try await sharedDatabase.allRecordZones()
                print("🔍 Fetching daily schedules from \(sharedZones.count) shared zones...")
                
                for zone in sharedZones {
                    print("   Checking shared zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                    
                    do {
                        let (records, _) = try await sharedDatabase.records(matching: query, inZoneWith: zone.zoneID)
                        let scheduleRecords = records.compactMap { _, result in
                            try? result.get()
                        }.compactMap { record in
                            DailyScheduleRecord(from: record)
                        }
                        
                        print("   ✅ Found \(scheduleRecords.count) daily schedules in shared zone \(zone.zoneID.zoneName)")
                        allScheduleRecords.append(contentsOf: scheduleRecords)
                        
                        // Log some sample records for debugging
                        for schedule in scheduleRecords.prefix(3) {
                            let dateStr = schedule.date?.description ?? "No date"
                            let line1 = schedule.line1 ?? ""
                            print("     📅 Shared Schedule: \(dateStr) - \(line1)")
                        }
                        
                    } catch {
                        print("   ❌ Error fetching from shared zone \(zone.zoneID.zoneName): \(error)")
                    }
                }
                
                await MainActor.run {
                    print("✅ Fetched \(allScheduleRecords.count) total daily schedules from all databases")
                    self.dailySchedules = allScheduleRecords
                    completion()
                }
            } catch {
                await MainActor.run {
                    print("❌ Error fetching zones or daily schedules: \(error)")
                    completion()
                }
            }
        }
    }
    
    private func fetchMonthlyNotes(completion: @escaping () -> Void) {
        let query = CKQuery(recordType: "CD_MonthlyNotes", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "CD_month", ascending: true)]
        
        Task {
            var allNotesRecords: [MonthlyNotesRecord] = []
            
            // Fetch from private database zones
            do {
                let privateZones = try await privateDatabase.allRecordZones()
                print("🔍 Fetching monthly notes from \(privateZones.count) private zones...")
                
                for zone in privateZones {
                    print("   Checking private zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                    
                    do {
                        let (records, _) = try await privateDatabase.records(matching: query, inZoneWith: zone.zoneID)
                        let notesRecords = records.compactMap { _, result in
                            try? result.get()
                        }.compactMap { record in
                            MonthlyNotesRecord(from: record)
                        }
                        
                        print("   ✅ Found \(notesRecords.count) monthly notes in private zone \(zone.zoneID.zoneName)")
                        allNotesRecords.append(contentsOf: notesRecords)
                        
                        // Log some sample records for debugging
                        for note in notesRecords.prefix(3) {
                            let line1 = note.line1 ?? ""
                            print("     📝 Private Note: \(note.month)/\(note.year) - \(line1)")
                        }
                        
                    } catch {
                        print("   ❌ Error fetching monthly notes from private zone \(zone.zoneID.zoneName): \(error)")
                    }
                }
                
                // Also fetch from shared database zones
                let sharedDatabase = container.sharedCloudDatabase
                let sharedZones = try await sharedDatabase.allRecordZones()
                print("🔍 Fetching monthly notes from \(sharedZones.count) shared zones...")
                
                for zone in sharedZones {
                    print("   Checking shared zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                    
                    do {
                        let (records, _) = try await sharedDatabase.records(matching: query, inZoneWith: zone.zoneID)
                        let notesRecords = records.compactMap { _, result in
                            try? result.get()
                        }.compactMap { record in
                            MonthlyNotesRecord(from: record)
                        }
                        
                        print("   ✅ Found \(notesRecords.count) monthly notes in shared zone \(zone.zoneID.zoneName)")
                        allNotesRecords.append(contentsOf: notesRecords)
                        
                        // Log some sample records for debugging
                        for note in notesRecords.prefix(3) {
                            let line1 = note.line1 ?? ""
                            print("     📝 Shared Note: \(note.month)/\(note.year) - \(line1)")
                        }
                        
                    } catch {
                        print("   ❌ Error fetching monthly notes from shared zone \(zone.zoneID.zoneName): \(error)")
                    }
                }
                
                await MainActor.run {
                    print("✅ Fetched \(allNotesRecords.count) total monthly notes from all databases")
                    self.monthlyNotes = allNotesRecords
                    completion()
                }
            } catch {
                await MainActor.run {
                    print("❌ Error fetching zones or monthly notes: \(error)")
                    completion()
                }
            }
        }
    }
    
        /// Check for accepted CloudKit shares that might contain calendar data
    func checkForAcceptedShares() async {
        print("🔍 ScheduleViewer: Checking for accepted CloudKit shares...")
        
        do {
            // Check private database for shared zones (Core Data + CloudKit puts shared records here)
            print("🔍 Checking private database for shared zones...")
            let privateZones = try await privateDatabase.allRecordZones()
            print("📊 Found \(privateZones.count) zones in private database:")
            
            for zone in privateZones {
                print("   Zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                
                // Check if this is a shared zone (owner is different from current user)
                if zone.zoneID.ownerName != "__defaultOwner__" {
                    print("   🔗 This appears to be a SHARED zone!")
                    
                    // Try to fetch calendar records from this shared zone
                    let query = CKQuery(recordType: "CD_DailySchedule", predicate: NSPredicate(value: true))
                    
                    do {
                        let (records, _) = try await privateDatabase.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 5)
                        print("   ✅ Found \(records.count) CD_DailySchedule records in shared zone!")
                        
                        for (_, result) in records {
                            if let record = try? result.get() {
                                let date = record["CD_date"] as? Date ?? Date()
                                let line1 = record["CD_line1"] as? String ?? ""
                                print("   📅 Shared Schedule: \(date) - \(line1)")
                            }
                        }
                    } catch {
                        print("   ❌ Error querying shared zone \(zone.zoneID.zoneName): \(error)")
                    }
                } else {
                    print("   ℹ️ This is a local zone (owner: __defaultOwner__)")
                }
            }
            
            // Also check shared database (for completeness)
            print("🔍 Also checking shared database...")
            let sharedDatabase = container.sharedCloudDatabase
            let sharedZones = try await sharedDatabase.allRecordZones()
            print("📊 Found \(sharedZones.count) zones in shared database:")
            
            for zone in sharedZones {
                print("   Shared Zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
            }
            
        } catch {
            print("❌ Error checking for accepted shares: \(error)")
        }
    }
    
    // acceptKnownShare method removed - use share URLs from share invitations instead
    
    /// Explicitly accept a CloudKit share from a URL
    func acceptShare(from url: URL) {
        print("🔗 ScheduleViewer: Attempting to accept CloudKit share from URL: \(url)")
        
        // Use the older completion-based API which is more reliable
        container.fetchShareMetadata(with: url) { shareMetadata, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to fetch share metadata: \(error)")
                    return
                }
                
                guard let shareMetadata = shareMetadata else {
                    print("❌ No share metadata returned")
                    return
                }
                
                print("✅ Fetched share metadata: \(shareMetadata)")
                print("   Share title: \(shareMetadata.share[CKShare.SystemFieldKey.title] ?? "No title")")
                if #available(iOS 16.0, *) {
                    print("   Root record ID: \(shareMetadata.rootRecord?.recordID.recordName ?? "Unknown")")
                } else {
                    print("   Root record ID: \(shareMetadata.rootRecordID.recordName)")
                }
                
                // Accept the share using modern iOS 15+ API
                let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [shareMetadata])
                acceptOperation.qualityOfService = .userInitiated
                
                // Handle individual share results
                acceptOperation.perShareResultBlock = { shareMetadata, shareResult in
                    DispatchQueue.main.async {
                        switch shareResult {
                        case .success(let share):
                            print("✅ Individual share accepted: \(share.recordID)")
                        case .failure(let error):
                            print("❌ Failed to accept share: \(shareMetadata.share.recordID) - \(error)")
                        }
                    }
                }
                
                // Handle overall operation completion
                acceptOperation.acceptSharesResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            print("✅ CloudKit share acceptance operation completed successfully!")
                            print("🔄 Refreshing data to show shared content...")
                            
                            // Wait a moment for CloudKit to sync, then refresh
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                self.fetchAllData()
                            }
                            
                        case .failure(let error):
                            print("❌ Failed to accept CloudKit shares: \(error)")
                        }
                    }
                }
                
                self.container.add(acceptOperation)
            }
        }
    }
}

// MARK: - Data Models
struct DailyScheduleRecord: Identifiable {
    let id: String
    let date: Date?
    let line1: String?
    let line2: String?
    let line3: String?
    
    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.date = record["CD_date"] as? Date
        self.line1 = record["CD_line1"] as? String
        self.line2 = record["CD_line2"] as? String
        self.line3 = record["CD_line3"] as? String
    }
}

struct MonthlyNotesRecord: Identifiable {
    let id: String
    let month: Int
    let year: Int
    let line1: String?
    let line2: String?
    let line3: String?
    
    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.month = Int((record["CD_month"] as? Int16) ?? 0)
        self.year = Int((record["CD_year"] as? Int16) ?? 0)
        self.line1 = record["CD_line1"] as? String
        self.line2 = record["CD_line2"] as? String
        self.line3 = record["CD_line3"] as? String
    }
}
