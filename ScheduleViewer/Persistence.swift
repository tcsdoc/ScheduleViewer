//
//  Persistence.swift
//  ScheduleViewer
//
//  Created by mark on 7/5/25.
//  Updated for CloudKit Private Database with Sharing support
//

import Foundation
import CloudKit
import SwiftUI

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    
    @Published var dailySchedules: [DailyScheduleRecord] = []
    @Published var monthlyNotes: [MonthlyNotesRecord] = []
    @Published var isLoading = false
    @Published var hasSharedData = false
    
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.gulfcoast.ProviderCalendar")
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase
        
        #if DEBUG
        print("🚀 ScheduleViewer CloudKitManager initialized for cross-Apple ID sharing")
        print("📊 Container: iCloud.com.gulfcoast.ProviderCalendar")
        print("🔗 Using private database with CloudKit sharing (matching Provider Schedule Calendar)")
        #endif
        
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
            print("🔄 CloudKit account changed - checking for data")
            #endif
            Task {
                await self?.fetchAllData()
            }
        }
    }
    
    func fetchAllData() async {
        await performFetchAllData()
    }
    
    private func performFetchAllData() async {
        self.isLoading = true
        
        #if DEBUG
        print("🔍 === ScheduleViewer: Cross-Apple ID Share Detection ===")
        #endif
        
        // Check CloudKit account status first
        do {
            let status = try await container.accountStatus()
            #if DEBUG
            switch status {
            case .available:
                print("✅ CloudKit account available")
            case .noAccount:
                print("❌ No iCloud account")
            case .restricted:
                print("❌ iCloud restricted")
            case .couldNotDetermine:
                print("❌ Could not determine iCloud status")
            case .temporarilyUnavailable:
                print("⚠️ iCloud temporarily unavailable")
            @unknown default:
                print("❓ Unknown iCloud status")
            }
            #endif
            
            guard status == .available else {
                #if DEBUG
                print("❌ CloudKit not available")
                #endif
                self.isLoading = false
                return
            }
            
            // Check all zones for data in private database (including shared zones)
            await checkAllZonesForData()
            
            // DISABLED: Provider Schedule Calendar now uses PRIVATE database with custom zones  
            // No more public database checking needed - all data is private and shared properly
            // await checkPublicDatabaseForData_DISABLED()
            
        } catch {
            #if DEBUG
            print("❌ Error checking CloudKit account status: \(error)")
            #endif
        }
        
        self.isLoading = false
    }
    
    /// Check all CloudKit zones for schedule data (private + shared databases)
    private func checkAllZonesForData() async {
        #if DEBUG
        print("🔍 Checking all CloudKit zones for schedule data...")
        #endif
        
        do {
            // Get all zones from private database  
            let privateZones = try await privateDatabase.allRecordZones()
            
            // Also check shared database (where accepted shares appear)
            let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
            
            let allZones = privateZones + sharedZones
            
            #if DEBUG
            print("📊 Found \(privateZones.count) zones in PRIVATE database")
            print("📊 Found \(sharedZones.count) zones in SHARED database") 
            print("📊 Total zones to check: \(allZones.count)")
            print("🔍 Looking for CloudKit record types: 'CD_DailySchedule' and 'CD_MonthlyNotes'")
            #endif
            
            var allDailySchedules: [DailyScheduleRecord] = []
            var allMonthlyNotes: [MonthlyNotesRecord] = []
            var foundSharedData = false
            
            for zone in allZones {
                #if DEBUG
                print("   Zone: \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                
                // Check if this is a shared zone from another Apple ID
                if zone.zoneID.ownerName != "__defaultOwner__" {
                    print("   🔗 *** SHARED ZONE DETECTED! ***")
                    print("   🔗 This zone is shared from: \(zone.zoneID.ownerName)")
                    
                    // Check if this is the specific zone we want from tcsdoc@mac.com
                    // Look for custom zones (will have format like "user_com.gulfcoast.ProviderCalendar")
                    if zone.zoneID.ownerName.contains("tcsdoc") || 
                       zone.zoneID.zoneName.contains("user_") {
                        print("   ✅ Found target zone from tcsdoc@mac.com!")
                        print("   🔒 Zone type: \(zone.zoneID.zoneName.contains("user_") ? "Custom Privacy Zone" : "Standard Zone")")
                    } else {
                        print("   ⚠️  This is a different user's zone - skipping")
                        print("   ⚠️  Looking for zones from tcsdoc@mac.com")
                        continue  // Skip this zone
                    }
                    foundSharedData = true
                } else {
                    print("   📱 This is your local zone")
                }
                #endif
                
                // Fetch daily schedules from this zone
                let dailyQuery = CKQuery(recordType: "CD_DailySchedule", predicate: NSPredicate(value: true))
                dailyQuery.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
                
                #if DEBUG
                print("   🔍 Searching for CD_DailySchedule records in zone \(zone.zoneID.zoneName)...")
                #endif
                
                // Use correct database based on zone location
                let database = privateZones.contains(where: { $0.zoneID == zone.zoneID }) ? privateDatabase : container.sharedCloudDatabase
                
                do {
                    let (dailyRecords, _) = try await database.records(matching: dailyQuery, inZoneWith: zone.zoneID, resultsLimit: 500)
                    
                    #if DEBUG
                    print("   📊 Raw query returned \(dailyRecords.count) daily schedule records")
                    if dailyRecords.count > 0 {
                        print("   📋 Sample records found:")
                        var recordCount = 0
                        for (recordID, result) in dailyRecords {
                            recordCount += 1
                            print("     Record \(recordCount): ID = \(recordID)")
                            if let record = try? result.get() {
                                print("       Date: \(record["CD_date"] as? Date ?? Date())")
                                print("       Line1: \(record["CD_line1"] as? String ?? "nil")")
                                print("       Line2: \(record["CD_line2"] as? String ?? "nil")")
                                print("       Line3: \(record["CD_line3"] as? String ?? "nil")")
                                if recordCount >= 3 { break }
                            }
                        }
                    }
                    #endif
                    
                    for (_, result) in dailyRecords {
                        if let record = try? result.get() {
                            let schedule = DailyScheduleRecord(
                                date: (record["CD_date"] as? Date) ?? Date(),
                                line1: record["CD_line1"] as? String,
                                line2: record["CD_line2"] as? String,
                                line3: record["CD_line3"] as? String
                            )
                            allDailySchedules.append(schedule)
                        }
                    }
                    
                    #if DEBUG
                    print("   ✅ Successfully processed \(dailyRecords.count) daily schedules in zone \(zone.zoneID.zoneName)")
                    #endif
                    
                } catch {
                    #if DEBUG
                    print("   ❌ Error fetching daily schedules from zone \(zone.zoneID.zoneName): \(error)")
                    #endif
                }
                
                // Fetch monthly notes from this zone
                let monthlyQuery = CKQuery(recordType: "CD_MonthlyNotes", predicate: NSPredicate(value: true))
                monthlyQuery.sortDescriptors = [NSSortDescriptor(key: "CD_year", ascending: true)]
                
                do {
                    let (monthlyRecords, _) = try await database.records(matching: monthlyQuery, inZoneWith: zone.zoneID, resultsLimit: 100)
                    
                    for (_, result) in monthlyRecords {
                        if let record = try? result.get() {
                            let note = MonthlyNotesRecord(
                                month: (record["CD_month"] as? Int64).map(Int.init) ?? 1,
                                year: (record["CD_year"] as? Int64).map(Int.init) ?? 2025,
                                line1: record["CD_line1"] as? String,
                                line2: record["CD_line2"] as? String,
                                line3: record["CD_line3"] as? String
                            )
                            allMonthlyNotes.append(note)
                        }
                    }
                    
                    #if DEBUG
                    print("   ✅ Found \(monthlyRecords.count) monthly notes in zone \(zone.zoneID.zoneName)")
                    #endif
                    
                } catch {
                    #if DEBUG
                    print("   ❌ Error fetching monthly notes from zone \(zone.zoneID.zoneName): \(error)")
                    #endif
                }
            }
            
            // Update the published properties (already on main actor)
            self.dailySchedules = allDailySchedules.sorted { $0.date < $1.date }
            self.monthlyNotes = allMonthlyNotes.sorted { $0.year < $1.year || ($0.year == $1.year && $0.month < $1.month) }
            self.hasSharedData = foundSharedData
            
            #if DEBUG
            print("📊 Total data loaded:")
            print("   Daily schedules: \(allDailySchedules.count)")
            print("   Monthly notes: \(allMonthlyNotes.count)")
            
            if allDailySchedules.count == 0 {
                print("❌ No schedule data found")
                print("💡 For cross-Apple ID sharing with tcsdoc@mac.com:")
                print("💡 1. Get a NEW CUSTOM ZONE share URL from tcsdoc@mac.com (Provider Schedule Calendar)")
                print("💡 2. Use 'Accept Share' button to paste the share URL")
                print("💡 3. Make sure the share is from tcsdoc@mac.com's CUSTOM ZONE (privacy-focused)")
                print("💡 4. Wait for CloudKit to sync the shared zone")
                print("💡 5. NEW: Provider Schedule Calendar now uses custom zones for data isolation")
                print("💡 Current zones found: \(allZones.map { $0.zoneID.ownerName }.joined(separator: ", "))")
                print("💡 Zone names: \(allZones.map { $0.zoneID.zoneName }.joined(separator: ", "))")
                print("💡 Private zones: \(privateZones.count), Shared zones: \(sharedZones.count)")
            }
            print("=== Data Sync Complete ===")
            #endif
            
        } catch {
            #if DEBUG
            print("❌ Error checking CloudKit zones: \(error)")
            #endif
        }
    }
    
    /// Check public database for schedule data (cross-Apple ID sharing)
    /// Re-enabled to check if Provider Schedule Calendar is actually using public database
    private func checkPublicDatabaseForData_DISABLED() async {
        #if DEBUG
        print("🌐 === Checking Public Database for Cross-Apple ID Data ===")
        print("🌐 Provider Schedule Calendar may use public database for sharing")
        #endif
        
        do {
            // Check for daily schedules in public database
            let dailyQuery = CKQuery(recordType: "CD_DailySchedule", predicate: NSPredicate(value: true))
            dailyQuery.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
            
            #if DEBUG
            print("🌐 Searching public database for CD_DailySchedule records...")
            #endif
            
            let (publicDailyRecords, _) = try await publicDatabase.records(matching: dailyQuery, resultsLimit: 500)
            
            #if DEBUG
            print("🌐 Found \(publicDailyRecords.count) daily schedules in public database")
            if publicDailyRecords.count > 0 {
                print("🌐 📋 Sample public records:")
                var recordCount = 0
                for (recordID, result) in publicDailyRecords {
                    recordCount += 1
                    print("     Public Record \(recordCount): ID = \(recordID)")
                    if let record = try? result.get() {
                        print("       Date: \(record["CD_date"] as? Date ?? Date())")
                        print("       Line1: \(record["CD_line1"] as? String ?? "nil")")
                        print("       Line2: \(record["CD_line2"] as? String ?? "nil")")
                        print("       Line3: \(record["CD_line3"] as? String ?? "nil")")
                        if recordCount >= 3 { break }
                    }
                }
            }
            #endif
            
            // Check for monthly notes in public database
            let monthlyQuery = CKQuery(recordType: "CD_MonthlyNotes", predicate: NSPredicate(value: true))
            monthlyQuery.sortDescriptors = [NSSortDescriptor(key: "CD_year", ascending: true)]
            
            let (publicMonthlyRecords, _) = try await publicDatabase.records(matching: monthlyQuery, resultsLimit: 100)
            
            #if DEBUG
            print("🌐 Found \(publicMonthlyRecords.count) monthly notes in public database")
            #endif
            
            // Process public database records if found
            if publicDailyRecords.count > 0 || publicMonthlyRecords.count > 0 {
                var publicDailySchedules: [DailyScheduleRecord] = []
                var publicMonthlyNotes: [MonthlyNotesRecord] = []
                
                // Process daily schedules
                for (_, result) in publicDailyRecords {
                    if let record = try? result.get() {
                        let schedule = DailyScheduleRecord(
                            date: (record["CD_date"] as? Date) ?? Date(),
                            line1: record["CD_line1"] as? String,
                            line2: record["CD_line2"] as? String,
                            line3: record["CD_line3"] as? String
                        )
                        publicDailySchedules.append(schedule)
                    }
                }
                
                // Process monthly notes
                for (_, result) in publicMonthlyRecords {
                    if let record = try? result.get() {
                        let note = MonthlyNotesRecord(
                            month: (record["CD_month"] as? Int64).map(Int.init) ?? 1,
                            year: (record["CD_year"] as? Int64).map(Int.init) ?? 2025,
                            line1: record["CD_line1"] as? String,
                            line2: record["CD_line2"] as? String,
                            line3: record["CD_line3"] as? String
                        )
                        publicMonthlyNotes.append(note)
                    }
                }
                
                // Use public database data if no private shared zones were found
                // Show public data for now to help with debugging
                if self.dailySchedules.isEmpty && self.monthlyNotes.isEmpty {
                    // For now, show ALL public data to see what's available
                    self.dailySchedules = publicDailySchedules.sorted { $0.date < $1.date }
                    self.monthlyNotes = publicMonthlyNotes.sorted { $0.year < $1.year || ($0.year == $1.year && $0.month < $1.month) }
                    self.hasSharedData = true
                    
                    #if DEBUG
                    print("🌐 ℹ️ Displaying PUBLIC database data (all users)")
                    print("🌐 ℹ️ This includes data from all Provider Schedule Calendar users")
                    print("🌐 ℹ️ Use 'Accept Share' to get specific shared data from tcsdoc@mac.com")
                    #endif
                }
                
                #if DEBUG
                print("🌐 ✅ Updated app with public database data:")
                print("🌐   Daily schedules: \(publicDailySchedules.count)")
                print("🌐   Monthly notes: \(publicMonthlyNotes.count)")
                print("🌐 === Public Database Check Complete ===")
                #endif
            } else {
                #if DEBUG
                print("🌐 ❌ No data found in public database")
                print("🌐 💡 Provider Schedule Calendar may not be using public database")
                print("🌐 💡 Or data hasn't been shared to public database yet")
                #endif
            }
            
        } catch {
            #if DEBUG
            print("🌐 ❌ Error checking public database: \(error)")
            if let ckError = error as? CKError {
                print("🌐 ❌ CK Error code: \(ckError.code.rawValue)")
                print("🌐 ❌ CK Error description: \(ckError.localizedDescription)")
            }
            #endif
        }
    }
    
    /// Accept CloudKit share from URL
    func acceptShare(from url: URL) {
        #if DEBUG
        print("🔗 === ScheduleViewer: Share Acceptance Started ===")
        print("🔗 URL: \(url.absoluteString)")
        print("🔗 Attempting to accept CloudKit share from URL")
        #endif
        
        // Validate URL format first - be more flexible with CloudKit share URLs
        let urlString = url.absoluteString.lowercased()
        let isValidCloudKitURL = urlString.contains("icloud.com") && urlString.contains("share")
        
        #if DEBUG
        print("🔍 URL Validation Details:")
        print("   Original URL: \(url.absoluteString)")
        print("   Host: \(url.host ?? "nil")")
        print("   Path: \(url.path)")
        print("   Contains icloud.com: \(urlString.contains("icloud.com"))")
        print("   Contains share: \(urlString.contains("share"))")
        print("   Is valid: \(isValidCloudKitURL)")
        #endif
        
        guard isValidCloudKitURL else {
            #if DEBUG
            print("❌ Invalid CloudKit share URL format")
            print("❌ Expected: https://www.icloud.com/share/... or https://share.icloud.com/...")
            print("❌ Received: \(url.absoluteString)")
            print("❌ URL components - Host: \(url.host ?? "nil"), Path: \(url.path)")
            print("💡 Common CloudKit share URL formats:")
            print("💡 - https://www.icloud.com/share/...")
            print("💡 - https://share.icloud.com/...")
            print("💡 Make sure to copy the complete share URL")
            #endif
            return
        }
        
        #if DEBUG
        print("✅ URL format validated")
        #endif
        
        // First get the share metadata from the URL
        let fetchOperation = CKFetchShareMetadataOperation(shareURLs: [url])
        fetchOperation.configuration.timeoutIntervalForRequest = 30
        fetchOperation.configuration.timeoutIntervalForResource = 60
        
        fetchOperation.fetchShareMetadataResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    #if DEBUG
                    print("✅ Share metadata fetch operation completed successfully")
                    #endif
                case .failure(let error):
                    #if DEBUG
                    print("❌ Share metadata fetch operation failed: \(error)")
                    if let nsError = error as NSError? {
                        print("❌ Error code: \(nsError.code)")
                        print("❌ Error domain: \(nsError.domain)")
                    }
                    #endif
                }
            }
        }
        
        fetchOperation.perShareMetadataResultBlock = { shareURL, result in
            DispatchQueue.main.async {
                switch result {
                case .success(let shareMetadata):
                    #if DEBUG
                    print("✅ Got share metadata for URL: \(shareURL)")
                    print("📊 Share metadata owner: \(shareMetadata.ownerIdentity.debugDescription)")
                    print("📊 Share metadata participant status: \(shareMetadata.participantStatus)")
                    print("📊 Share metadata container: \(shareMetadata.containerIdentifier)")
                    #endif
                    
                    // Check if we're already a participant
                    if shareMetadata.participantStatus == .accepted {
                        #if DEBUG
                        print("ℹ️ Share already accepted, reloading data...")
                        #endif
                        Task {
                            await self.fetchAllData()
                        }
                        return
                    }
                    
                    // Now accept the share using the metadata
                    let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [shareMetadata])
                    acceptOperation.configuration.timeoutIntervalForRequest = 30
                    
                    acceptOperation.perShareResultBlock = { shareMetadata, result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let share):
                                #if DEBUG
                                print("✅ Successfully accepted share for metadata: \(shareMetadata)")
                                print("✅ Share details: \(share)")
                                #endif
                            case .failure(let error):
                                #if DEBUG
                                print("❌ Failed to accept specific share: \(error)")
                                #endif
                            }
                        }
                    }
                    
                    acceptOperation.acceptSharesResultBlock = { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success():
                                #if DEBUG
                                print("✅ Successfully accepted CloudKit share!")
                                print("🔄 Waiting 8 seconds for CloudKit to process, then reloading data...")
                                #endif
                                // Wait longer for CloudKit to process, then reload
                                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                                    Task {
                                        await self.fetchAllData()
                                    }
                                }
                            case .failure(let error):
                                #if DEBUG
                                print("❌ Failed to accept CloudKit share: \(error)")
                                if let nsError = error as NSError? {
                                    print("❌ Error code: \(nsError.code)")
                                }
                                print("❌ Error description: \(error.localizedDescription)")
                                if let ckError = error as? CKError {
                                    print("❌ CK Error code: \(ckError.code.rawValue)")
                                    print("❌ CK Error user info: \(ckError.userInfo)")
                                }
                                #endif
                            }
                        }
                    }
                    
                    self.container.add(acceptOperation)
                    
                case .failure(let error):
                    #if DEBUG
                    print("❌ Failed to get share metadata for URL: \(shareURL)")
                    print("❌ Error: \(error)")
                    if let nsError = error as NSError? {
                        print("❌ Error code: \(nsError.code)")
                    }
                    if let ckError = error as? CKError {
                        print("❌ CK Error code: \(ckError.code.rawValue)")
                        print("❌ CK Error description: \(ckError.localizedDescription)")
                        print("❌ CK Error user info: \(ckError.userInfo)")
                        
                        switch ckError.code {
                        case .unknownItem:
                            print("💡 Share not found - this could mean:")
                            print("💡 1. The share URL is invalid or expired")
                            print("💡 2. The share was revoked by the owner")
                            print("💡 3. You don't have permission to access this share")
                            print("💡 4. Try asking the share owner to send a new share URL")
                        case .networkFailure, .networkUnavailable:
                            print("💡 Network issue - check your internet connection")
                        case .notAuthenticated:
                            print("💡 Not signed into iCloud - check Settings > [Your Name] > iCloud")
                        default:
                            print("💡 Unknown CloudKit error - try again later")
                        }
                    }
                    #endif
                }
            }
        }
        
        container.add(fetchOperation)
    }
    
    /// Legacy check function for debugging
    func checkForAcceptedShares() async {
        await checkAllZonesForData()
    }
}

// MARK: - Data Record Types
struct DailyScheduleRecord: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let line1: String?
    let line2: String?
    let line3: String?
    
    init(date: Date, line1: String?, line2: String?, line3: String?) {
        self.id = UUID()
        self.date = date
        self.line1 = line1?.isEmpty == true ? nil : line1
        self.line2 = line2?.isEmpty == true ? nil : line2
        self.line3 = line3?.isEmpty == true ? nil : line3
    }
}

struct MonthlyNotesRecord: Identifiable, Hashable {
    let id: UUID
    let month: Int
    let year: Int
    let line1: String?
    let line2: String?
    let line3: String?
    
    init(month: Int, year: Int, line1: String?, line2: String?, line3: String?) {
        self.id = UUID()
        self.month = month
        self.year = year
        self.line1 = line1?.isEmpty == true ? nil : line1
        self.line2 = line2?.isEmpty == true ? nil : line2
        self.line3 = line3?.isEmpty == true ? nil : line3
    }
}