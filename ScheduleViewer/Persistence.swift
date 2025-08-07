//
//  Persistence.swift
//  ScheduleViewer
//
//  Created by mark on 7/5/25.
//  Updated for Core Data + CloudKit Private Database integration
//

import Foundation
import CloudKit

@MainActor
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
        ) { [weak self] _ in
            #if DEBUG
            print("🔄 CloudKit account changed - checking for new shares")
            #endif
            self?.fetchAllData()
        }
    }
    
    nonisolated func fetchAllData() {
        Task { @MainActor in
            await performFetchAllData()
        }
    }
    
    @MainActor
    private func performFetchAllData() async {
        isLoading = true
        
        // Check CloudKit account status first (async version)
        do {
            let status = try await container.accountStatus()
            #if DEBUG
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
            #endif
        } catch {
            #if DEBUG
            print("❌ Error checking CloudKit account status: \(error)")
            #endif
        }
        
        // Use async/await pattern for cleaner code
        async let dailySchedules = fetchAllDailySchedules()
        async let monthlyNotes = fetchAllMonthlyNotes()
        
        do {
            let (schedules, notes) = try await (dailySchedules, monthlyNotes)
            
            self.dailySchedules = schedules
            self.monthlyNotes = notes
            
            #if DEBUG
            print("✅ Fetched \(schedules.count) daily schedules and \(notes.count) monthly notes")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error fetching data: \(error)")
            #endif
        }
        
        #if DEBUG
        print("🏁 ScheduleViewer: Data fetch completed")
        #endif
        isLoading = false
    }
    
    private func fetchAllDailySchedules() async throws -> [DailyScheduleRecord] {
        var allSchedules: [DailyScheduleRecord] = []
        
        // Get all zones from private database (includes both local and shared zones)
        let privateZones = try await privateDatabase.allRecordZones()
        
        #if DEBUG
        print("🔍 Fetching daily schedules from \(privateZones.count) private zones...")
        #endif
        
        for zone in privateZones {
            #if DEBUG
            print("   Checking private zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
            #endif
            
            // Create a date range predicate to ensure we get data well into the future
            let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
            let datePredicate = NSPredicate(format: "CD_date >= %@ AND CD_date <= %@", startDate as NSDate, endDate as NSDate)
            
            let query = CKQuery(recordType: "CD_DailySchedule", predicate: datePredicate)
            query.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
            
            do {
                let (records, _) = try await privateDatabase.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 500)
                
                let scheduleRecords = records.compactMap { (_, result) -> DailyScheduleRecord? in
                    guard let record = try? result.get() else { return nil }
                    return DailyScheduleRecord(from: record)
                }
                
                allSchedules.append(contentsOf: scheduleRecords)
                
                #if DEBUG
                print("   ✅ Found \(scheduleRecords.count) daily schedules in private zone \(zone.zoneID.zoneName)")
                
                // Log date range for debugging
                let sortedSchedules = scheduleRecords.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
                if let firstDate = sortedSchedules.first?.date, let lastDate = sortedSchedules.last?.date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    print("     📅 Date range: \(formatter.string(from: firstDate)) to \(formatter.string(from: lastDate))")
                }
                
                // Log some sample records for debugging (non-sensitive data only)
                for schedule in scheduleRecords.prefix(3) {
                    let dateStr = schedule.date?.description ?? "No date"
                    let line1 = schedule.line1 ?? "No data"
                    print("     📅 Private Schedule: \(dateStr) - \(line1)")
                }
                #endif
            } catch {
                #if DEBUG
                print("   ❌ Error fetching from private zone \(zone.zoneID.zoneName): \(error)")
                #endif
            }
        }
        
        // Also check shared database
        let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
        
        #if DEBUG
        print("🔍 Fetching daily schedules from \(sharedZones.count) shared zones...")
        #endif
        
        for zone in sharedZones {
            #if DEBUG
            print("   Checking shared zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
            #endif
            
            // Create a date range predicate to ensure we get data well into the future
            let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
            let datePredicate = NSPredicate(format: "CD_date >= %@ AND CD_date <= %@", startDate as NSDate, endDate as NSDate)
            
            let query = CKQuery(recordType: "CD_DailySchedule", predicate: datePredicate)
            query.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
            
            do {
                let (records, _) = try await container.sharedCloudDatabase.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 500)
                
                let scheduleRecords = records.compactMap { (_, result) -> DailyScheduleRecord? in
                    guard let record = try? result.get() else { return nil }
                    return DailyScheduleRecord(from: record)
                }
                
                allSchedules.append(contentsOf: scheduleRecords)
                
                #if DEBUG
                print("   ✅ Found \(scheduleRecords.count) daily schedules in shared zone \(zone.zoneID.zoneName)")
                
                // Log date range for debugging
                let sortedSchedules = scheduleRecords.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
                if let firstDate = sortedSchedules.first?.date, let lastDate = sortedSchedules.last?.date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    print("     📅 Date range: \(formatter.string(from: firstDate)) to \(formatter.string(from: lastDate))")
                }
                
                // Log some sample records for debugging (non-sensitive data only)
                for schedule in scheduleRecords.prefix(3) {
                    let dateStr = schedule.date?.description ?? "No date"
                    let line1 = schedule.line1 ?? "No data"
                    print("     📅 Shared Schedule: \(dateStr) - \(line1)")
                }
                #endif
            } catch {
                #if DEBUG
                print("   ❌ Error fetching from shared zone \(zone.zoneID.zoneName): \(error)")
                #endif
            }
        }
        
        return allSchedules
    }
    
    private func fetchAllMonthlyNotes() async throws -> [MonthlyNotesRecord] {
        var allNotes: [MonthlyNotesRecord] = []
        
        // Get all zones from private database (includes both local and shared zones)
        let privateZones = try await privateDatabase.allRecordZones()
        
        #if DEBUG
        print("🔍 Fetching monthly notes from \(privateZones.count) private zones...")
        #endif
        
        for zone in privateZones {
            #if DEBUG
            print("   Checking private zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
            #endif
            
            let query = CKQuery(recordType: "CD_MonthlyNotes", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "CD_year", ascending: true), NSSortDescriptor(key: "CD_month", ascending: true)]
            
            do {
                let (records, _) = try await privateDatabase.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 100)
                
                let notesRecords = records.compactMap { (_, result) -> MonthlyNotesRecord? in
                    guard let record = try? result.get() else { return nil }
                    return MonthlyNotesRecord(from: record)
                }
                
                allNotes.append(contentsOf: notesRecords)
                
                #if DEBUG
                print("   ✅ Found \(notesRecords.count) monthly notes in private zone \(zone.zoneID.zoneName)")
                
                // Log some sample records for debugging (non-sensitive data only)
                for note in notesRecords.prefix(2) {
                    let line1 = note.line1 ?? "No data"
                    print("     📝 Private Note: \(note.month)/\(note.year) - \(line1)")
                }
                #endif
            } catch {
                #if DEBUG
                print("   ❌ Error fetching monthly notes from private zone \(zone.zoneID.zoneName): \(error)")
                #endif
            }
        }
        
        // Also check shared database
        let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
        
        #if DEBUG
        print("🔍 Fetching monthly notes from \(sharedZones.count) shared zones...")
        #endif
        
        for zone in sharedZones {
            #if DEBUG
            print("   Checking shared zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
            #endif
            
            let query = CKQuery(recordType: "CD_MonthlyNotes", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "CD_year", ascending: true), NSSortDescriptor(key: "CD_month", ascending: true)]
            
            do {
                let (records, _) = try await container.sharedCloudDatabase.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 100)
                
                let notesRecords = records.compactMap { (_, result) -> MonthlyNotesRecord? in
                    guard let record = try? result.get() else { return nil }
                    return MonthlyNotesRecord(from: record)
                }
                
                allNotes.append(contentsOf: notesRecords)
                
                #if DEBUG
                print("   ✅ Found \(notesRecords.count) monthly notes in shared zone \(zone.zoneID.zoneName)")
                
                // Log some sample records for debugging (non-sensitive data only)
                for note in notesRecords.prefix(2) {
                    let line1 = note.line1 ?? "No data"
                    print("     📝 Shared Note: \(note.month)/\(note.year) - \(line1)")
                }
                #endif
            } catch {
                #if DEBUG
                print("   ❌ Error fetching monthly notes from shared zone \(zone.zoneID.zoneName): \(error)")
                #endif
            }
        }
        
        return allNotes
    }
    
    func checkForAcceptedShares() async {
        #if DEBUG
        print("🔍 ScheduleViewer: Checking for accepted CloudKit shares...")
        #endif
        
        do {
            // Check private database for shared zones (Core Data + CloudKit puts shared records here)
            #if DEBUG
            print("🔍 Checking private database for shared zones...")
            #endif
            let privateZones = try await privateDatabase.allRecordZones()
            #if DEBUG
            print("📊 Found \(privateZones.count) zones in private database:")
            #endif
            
            for zone in privateZones {
                #if DEBUG
                print("   Zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                #endif
                
                // Check if this is a shared zone (owner is different from current user)
                if zone.zoneID.ownerName != "__defaultOwner__" {
                    #if DEBUG
                    print("   🔗 This appears to be a SHARED zone!")
                    #endif
                    
                    // Try to fetch calendar records from this shared zone
                    let query = CKQuery(recordType: "CD_DailySchedule", predicate: NSPredicate(value: true))
                    
                    do {
                        let (records, _) = try await privateDatabase.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: 5)
                        #if DEBUG
                        print("   ✅ Found \(records.count) CD_DailySchedule records in shared zone!")
                        #endif
                        
                        #if DEBUG
                        for (_, result) in records {
                            if let record = try? result.get() {
                                let date = record["CD_date"] as? Date ?? Date()
                                let line1 = record["CD_line1"] as? String ?? ""
                                print("   📅 Shared Schedule: \(date) - \(line1)")
                            }
                        }
                        #endif
                    } catch {
                        #if DEBUG
                        print("   ❌ Error querying shared zone \(zone.zoneID.zoneName): \(error)")
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("   ℹ️ This is a local zone (owner: __defaultOwner__)")
                    #endif
                }
            }
            
            // Also check the shared database itself
            #if DEBUG
            print("🔍 Also checking shared database...")
            #endif
            let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
            #if DEBUG
            print("📊 Found \(sharedZones.count) zones in shared database:")
            #endif
            
            for zone in sharedZones {
                #if DEBUG
                print("   Shared Zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                #endif
            }
            
        } catch {
            #if DEBUG
            print("❌ Error checking for accepted shares: \(error)")
            #endif
        }
    }
    
    func acceptShare(from url: URL) {
        #if DEBUG
        print("🔗 ScheduleViewer: Attempting to accept CloudKit share from URL")
        #endif
        
        // Use the older completion-based API which is more reliable
        container.fetchShareMetadata(with: url) { [weak self] shareMetadata, error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("❌ Failed to fetch share metadata: \(error)")
                    #endif
                    return
                }
                
                guard let shareMetadata = shareMetadata else {
                    #if DEBUG
                    print("❌ No share metadata returned")
                    #endif
                    return
                }
                
                #if DEBUG
                print("✅ Fetched share metadata: \(shareMetadata)")
                print("   Share title: \(shareMetadata.share[CKShare.SystemFieldKey.title] ?? "No title")")
                if #available(iOS 16.0, *) {
                    print("   Root record ID: \(shareMetadata.rootRecord?.recordID.recordName ?? "Unknown")")
                } else {
                    print("   Root record ID: \(shareMetadata.rootRecordID.recordName)")
                }
                #endif
                
                // Accept the share using modern iOS 15+ API
                let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [shareMetadata])
                acceptOperation.qualityOfService = .userInitiated
                
                // Handle individual share results
                acceptOperation.perShareResultBlock = { shareMetadata, shareResult in
                    DispatchQueue.main.async {
                        switch shareResult {
                        case .success(let share):
                            #if DEBUG
                            print("✅ Individual share accepted: \(share.recordID)")
                            #endif
                        case .failure(let error):
                            #if DEBUG
                            print("❌ Failed to accept share: \(shareMetadata.share.recordID) - \(error)")
                            #endif
                        }
                    }
                }
                
                // Handle overall completion
                acceptOperation.acceptSharesResultBlock = { [weak self] result in
                    Task { @MainActor in
                        switch result {
                        case .success:
                            #if DEBUG
                            print("✅ CloudKit share acceptance operation completed successfully!")
                            print("🔄 Refreshing data to show shared content...")
                            #endif
                            
                            // Refresh data to show the newly shared content
                            self?.fetchAllData()
                            
                        case .failure(let error):
                            #if DEBUG
                            print("❌ Failed to accept CloudKit shares: \(error)")
                            #endif
                        }
                    }
                }
                
                // Execute the operation
                self?.container.add(acceptOperation)
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
        self.month = (record["CD_month"] as? Int64).map(Int.init) ?? 0
        self.year = (record["CD_year"] as? Int64).map(Int.init) ?? 0
        self.line1 = record["CD_line1"] as? String
        self.line2 = record["CD_line2"] as? String
        self.line3 = record["CD_line3"] as? String
    }
}
