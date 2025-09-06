import Foundation
import CloudKit
import SwiftUI

// MARK: - Debug Logging Helper
func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let sharedDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    
    @Published var sharedSchedules: [SharedScheduleRecord] = []
    @Published var sharedMonthlyNotes: [SharedMonthlyNotesRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cloudKitAvailable = false
    @Published var acceptedShares: [CKShare] = []
    
    private var acceptedSharedZones: [CKRecordZone.ID] = [] {
        didSet {
            // Persist to UserDefaults whenever this changes
            saveAcceptedSharedZonesToDefaults()
        }
    }
    
    init() {
        container = CKContainer(identifier: "iCloud.com.gulfcoast.ProviderCalendar")
        sharedDatabase = container.sharedCloudDatabase
        privateDatabase = container.privateCloudDatabase
        
        debugLog("🚀 ScheduleViewer CloudKitManager initialized (Shared + Private Database Access)")
        
        // Load any previously accepted shared zones
        loadAcceptedSharedZonesFromDefaults()
        
        checkCloudKitStatus()
    }
    
    // MARK: - Share Persistence
    private func saveAcceptedSharedZonesToDefaults() {
        let zoneData = acceptedSharedZones.compactMap { zone -> [String: String]? in
            return [
                "zoneName": zone.zoneName,
                "ownerName": zone.ownerName
            ]
        }
        UserDefaults.standard.set(zoneData, forKey: "acceptedSharedZones")
        debugLog("💾 Saved \(zoneData.count) accepted shared zones to UserDefaults")
    }
    
    private func loadAcceptedSharedZonesFromDefaults() {
        guard let zoneData = UserDefaults.standard.array(forKey: "acceptedSharedZones") as? [[String: String]] else {
            debugLog("📂 No previously accepted shared zones found in UserDefaults")
            return
        }
        
        acceptedSharedZones = zoneData.compactMap { dict in
            guard let zoneName = dict["zoneName"],
                  let ownerName = dict["ownerName"] else { return nil }
            return CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        }
        
        debugLog("📂 Loaded \(acceptedSharedZones.count) accepted shared zones from UserDefaults")
        
        // If we have persisted zones, we should automatically fetch data
        if !acceptedSharedZones.isEmpty {
            debugLog("🔄 Auto-fetching data from \(acceptedSharedZones.count) persisted shared zones")
            fetchSharedSchedules()
        }
    }
    
    private func clearAcceptedSharedZones() {
        acceptedSharedZones = []
        UserDefaults.standard.removeObject(forKey: "acceptedSharedZones")
        debugLog("🗑️ Cleared all accepted shared zones from UserDefaults")
    }
    
    // MARK: - CloudKit Account Status
    private func checkCloudKitStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.cloudKitAvailable = true
                    self?.errorMessage = nil
                    debugLog("✅ CloudKit available for ScheduleViewer")
                case .noAccount:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "Please sign in to iCloud to view shared schedules."
                    debugLog("❌ CloudKit unavailable - no iCloud account")
                case .restricted:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "iCloud access is restricted."
                    debugLog("❌ CloudKit restricted")
                case .couldNotDetermine:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "Unable to determine iCloud status."
                    debugLog("❌ CloudKit status unknown")
                case .temporarilyUnavailable:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "iCloud is temporarily unavailable."
                    debugLog("⚠️ CloudKit temporarily unavailable")
                @unknown default:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "Unknown iCloud status."
                    debugLog("❓ CloudKit unknown status")
                }
            }
        }
    }
    
    // MARK: - Share Management
    func checkForSharedData() {
        debugLog("🔍 Checking for shared data...")
        
        guard cloudKitAvailable else {
            debugLog("❌ CloudKit not available - cannot check for shared data")
            return
        }
        
        isLoading = true
        
        // First, discover any shared zones
        discoverSharedZones { [weak self] in
            // Then fetch data from those zones
            self?.fetchSharedSchedules()
        }
    }
    
    private func discoverSharedZones(completion: @escaping () -> Void) {
        debugLog("🔍 Discovering shared zones...")
        
        Task {
            do {
                let sharedZones = try await sharedDatabase.allRecordZones()
                debugLog("✅ Discovered \(sharedZones.count) shared zones")
                
                DispatchQueue.main.async {
                    self.acceptedSharedZones = sharedZones.map { $0.zoneID }
                    
                    for (index, zone) in sharedZones.enumerated() {
                        debugLog("🔒 Shared zone \(index + 1): \(zone.zoneID.zoneName) (owner: \(zone.zoneID.ownerName))")
                        debugLog("    Zone capabilities: \(zone.capabilities)")
                        debugLog("    Zone share: \(zone.share?.recordID.recordName ?? "no share info")")
                    }
                    
                    // Also check if there are any other zones we might be missing
                    if sharedZones.count == 1 {
                        debugLog("⚠️ Only found 1 shared zone. Expected to find zones with Sept 2, 18, and 23 data.")
                        debugLog("💡 This suggests the Sept 2 and 18 records may be in a different zone or not properly shared.")
                    }
                    
                    completion()
                }
            } catch {
                debugLog("❌ Failed to discover shared zones: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to discover shared data: \(error.localizedDescription)"
                    completion()
                }
            }
        }
    }
    
    private func fetchSharedSchedules() {
        debugLog("📅 Fetching shared schedules AND monthly notes from \(acceptedSharedZones.count) zones...")
        
        guard !acceptedSharedZones.isEmpty else {
            debugLog("⚠️ No shared zones available")
            isLoading = false
            return
        }
        
        isLoading = true
        var allSchedules: [SharedScheduleRecord] = []
        var allMonthlyNotes: [SharedMonthlyNotesRecord] = []
        let group = DispatchGroup()
        
        // Query each shared zone individually with proper pagination
        for zoneID in acceptedSharedZones {
            group.enter()
            debugLog("🔍 Querying zone: \(zoneID.zoneName) for CD_DailySchedule records")
            debugLog("💭 PSC showed 3 records in CloudKit Console: Sept 2, Sept 18, Sept 23")
            
            fetchRecordsInZone(zoneID: zoneID, cursor: nil) { zoneRecords in
                self.processZoneRecords(zoneRecords, from: zoneID, into: &allSchedules)
                
                // CRITICAL FIX: Only check private database if this is OUR zone
                // Shared zones from other users can't be accessed via private database
                if zoneID.ownerName == CKCurrentUserDefaultName {
                    debugLog("🔄 ALSO checking PRIVATE database for our own zone...")
                    group.enter()
                    self.queryPrivateDatabase(zoneID: zoneID) { privateSchedules in
                        allSchedules.append(contentsOf: privateSchedules)
                        group.leave()
                    }
                } else {
                    debugLog("🔍 SHARED ZONE from another user (\(zoneID.ownerName)) - skipping private DB query")
                    debugLog("💡 SHARED DATABASE should contain all shared records from this zone")
                }
                group.leave()
            }
        }
        
        // Query each shared zone for monthly notes
        for zoneID in acceptedSharedZones {
            group.enter()
            debugLog("🔍 Querying zone: \(zoneID.zoneName) for CD_MonthlyNotes records")
            
            fetchMonthlyNotesInZone(zoneID: zoneID) { zoneNotes in
                allMonthlyNotes.append(contentsOf: zoneNotes)
                debugLog("📝 Found \(zoneNotes.count) monthly notes in zone \(zoneID.zoneName)")
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            // Remove duplicates by record ID (same record might be in both shared and private)
            let uniqueSchedules = Dictionary(grouping: allSchedules, by: { $0.id })
                .values
                .compactMap { $0.first }
                .sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
            
            let uniqueMonthlyNotes = Dictionary(grouping: allMonthlyNotes, by: { $0.id })
                .values
                .compactMap { $0.first }
                .sorted { ($0.year * 100 + $0.month) < ($1.year * 100 + $1.month) }
            
            self?.sharedSchedules = uniqueSchedules
            self?.sharedMonthlyNotes = uniqueMonthlyNotes
            debugLog("✅ Total fetched schedules (after deduplication): \(uniqueSchedules.count) from \(allSchedules.count) total results")
            debugLog("✅ Total fetched monthly notes (after deduplication): \(uniqueMonthlyNotes.count) from \(allMonthlyNotes.count) total results")
            debugLog("🎯 FINAL RESULT: SV will display \(uniqueSchedules.count) schedules and \(uniqueMonthlyNotes.count) monthly notes")
        }
    }
    
    private func fetchRecordsInZone(zoneID: CKRecordZone.ID, cursor: CKQueryOperation.Cursor?, completion: @escaping ([CKRecord]) -> Void) {
        var zoneRecords: [CKRecord] = []
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "CD_DailySchedule", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
        
        let queryOperation = cursor == nil ? CKQueryOperation(query: query) : CKQueryOperation(cursor: cursor!)
        queryOperation.zoneID = zoneID
        queryOperation.resultsLimit = 100
        
        debugLog("⚙️ Query operation config: zone=\(zoneID.zoneName), limit=\(queryOperation.resultsLimit), cursor=\(cursor != nil ? "yes" : "no")")
        
        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                zoneRecords.append(record)
                let dateStr = (record["CD_date"] as? Date)?.description ?? "nil"
                let line1 = record["CD_line1"] as? String ?? "nil"
                debugLog("📋 Found record: \(recordID.recordName) - Date: \(dateStr) - Line1: \(line1)")
            case .failure(let error):
                debugLog("❌ Failed to process record \(recordID): \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cursor):
                    debugLog("📊 Query completed for zone \(zoneID.zoneName): \(zoneRecords.count) records")
                    if let cursor = cursor {
                        debugLog("🔄 PAGINATION: Fetching more records with cursor")
                        self.fetchRecordsInZone(zoneID: zoneID, cursor: cursor) { additionalRecords in
                            completion(zoneRecords + additionalRecords)
                        }
                    } else {
                        debugLog("✅ All records fetched (no cursor)")
                        // Debug analysis for troubleshooting
                        if zoneRecords.count == 1 && zoneID.zoneName == "user_com.gulfcoast.ProviderCalendar" {
                            debugLog("🔍 DEBUGGING: Only 1 record found in main zone. Let's check what dates exist...")
                            for record in zoneRecords {
                                let date = record["CD_date"] as? Date
                                let formatter = DateFormatter()
                                formatter.dateFormat = "MMM dd, yyyy"
                                debugLog("🗓️ Found date: \(formatter.string(from: date ?? Date()))")
                            }
                            debugLog("💭 Expected dates: Sept 2, Sept 18, Sept 23, 2025")
                            debugLog("💡 THEORY: Sept 2 and Sept 18 records may have been overwritten or are in a different zone")
                        }
                        completion(zoneRecords)
                    }
                case .failure(let error):
                    debugLog("❌ Query failed for zone \(zoneID.zoneName): \(error)")
                    completion(zoneRecords)
                }
            }
        }
        
        sharedDatabase.add(queryOperation)
    }
    
    private func processZoneRecords(_ records: [CKRecord], from zoneID: CKRecordZone.ID, into allSchedules: inout [SharedScheduleRecord]) {
        debugLog("📊 Processing \(records.count) records from zone \(zoneID.zoneName)")
        
        // Debug each raw record first
        for (index, record) in records.enumerated() {
            let date = record["CD_date"] as? Date
            let line1 = record["CD_line1"] as? String
            let line2 = record["CD_line2"] as? String
            let line3 = record["CD_line3"] as? String
            debugLog("📋 Raw Record \(index + 1): \(record.recordID.recordName)")
            debugLog("  📅 Date: \(date?.description ?? "nil")")
            debugLog("  📝 Line1: \(line1 ?? "nil")")
            debugLog("  📝 Line2: \(line2 ?? "nil")")
            debugLog("  📝 Line3: \(line3 ?? "nil")")
        }
        
        let schedules = records.map(SharedScheduleRecord.init)
        allSchedules.append(contentsOf: schedules)
        debugLog("✅ Converted \(schedules.count) schedules from zone \(zoneID.zoneName)")
        
        for (index, schedule) in schedules.enumerated() {
            debugLog("📅 Schedule \(index + 1): \(schedule.date?.description ?? "nil") - \(schedule.line1 ?? "nil")")
        }
    }
    
    // MARK: - Share Acceptance
    func acceptShareFromURL(_ url: URL, completion: @escaping (Bool, Error?) -> Void) {
        debugLog("🔗 Accepting share from URL: \(url)")
        
        guard cloudKitAvailable else {
            debugLog("❌ CloudKit not available")
            completion(false, NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit not available"]))
            return
        }
        
        // Fetch share metadata first
        let fetchOperation = CKFetchShareMetadataOperation(shareURLs: [url])
        fetchOperation.perShareMetadataResultBlock = { shareURL, result in
            switch result {
            case .success(let metadata):
                debugLog("✅ Fetched share metadata successfully")
                self.acceptShare(metadata: metadata, completion: completion)
            case .failure(let error):
                debugLog("❌ Failed to fetch share metadata: \(error)")
                completion(false, error)
            }
        }
        
        fetchOperation.fetchShareMetadataResultBlock = { result in
            switch result {
            case .success:
                debugLog("✅ Fetch share metadata operation completed")
            case .failure(let error):
                debugLog("❌ Fetch share metadata operation failed: \(error)")
                completion(false, error)
            }
        }
        
        container.add(fetchOperation)
    }
    
    private func acceptShare(metadata: CKShare.Metadata, completion: @escaping (Bool, Error?) -> Void) {
        debugLog("🔗 Accepting share with metadata")
        
        let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        acceptOperation.perShareResultBlock = { metadata, result in
            switch result {
            case .success(let share):
                debugLog("✅ Successfully accepted share")
                DispatchQueue.main.async { [weak self] in
                    self?.acceptedShares.append(share)
                    // Immediately discover and persist the new shared zones
                    self?.discoverSharedZones {
                        debugLog("🔄 Share zones updated after acceptance")
                    }
                    completion(true, nil)
                }
            case .failure(let error):
                debugLog("❌ Failed to accept share: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
        
        acceptOperation.acceptSharesResultBlock = { result in
            switch result {
            case .success:
                debugLog("✅ Accept shares operation completed")
            case .failure(let error):
                debugLog("❌ Accept shares operation failed: \(error)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
        
        container.add(acceptOperation)
    }
    
    func refreshAfterShareAcceptance() {
        debugLog("🔗 Refreshing data after share acceptance")
        checkForSharedData()
    }
    
    private func queryPrivateDatabase(zoneID: CKRecordZone.ID, completion: @escaping ([SharedScheduleRecord]) -> Void) {
        debugLog("🔍 PRIVATE DB - Querying zone: \(zoneID.zoneName) for CD_DailySchedule records")
        debugLog("💡 THEORY: PSC saves to private DB, so the missing Sept 2 & 18 records should be here!")
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "CD_DailySchedule", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
        
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        queryOperation.resultsLimit = 100
        
        debugLog("⚙️ PRIVATE DB query config: zone=\(zoneID.zoneName), limit=\(queryOperation.resultsLimit)")
        
        var privateRecords: [CKRecord] = []
        
        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                privateRecords.append(record)
                let dateStr = (record["CD_date"] as? Date)?.description ?? "nil"
                let line1 = record["CD_line1"] as? String ?? "nil"
                debugLog("📋 PRIVATE DB - Found record: \(recordID.recordName) - Date: \(dateStr) - Line1: \(line1)")
            case .failure(let error):
                debugLog("❌ PRIVATE DB - Failed to process record \(recordID): \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    debugLog("📊 PRIVATE DB query completed for zone \(zoneID.zoneName): \(privateRecords.count) records")
                    if privateRecords.count >= 3 {
                        debugLog("🎯 BINGO! PRIVATE database found \(privateRecords.count) records - likely all 3 missing schedules!")
                    } else if privateRecords.count > 0 {
                        debugLog("🔍 PRIVATE database found \(privateRecords.count) records")
                    } else {
                        debugLog("⚠️ PRIVATE database also returned 0 records - unexpected!")
                    }
                    
                    // Convert to schedules and return
                    let schedules = privateRecords.map(SharedScheduleRecord.init)
                    debugLog("✅ PRIVATE DB - Converted \(schedules.count) schedules")
                    completion(schedules)
                    
                case .failure(let error):
                    debugLog("❌ PRIVATE DB query failed for zone \(zoneID.zoneName): \(error)")
                    completion([])
                }
            }
        }
        
        // Add the operation to the PRIVATE database
        privateDatabase.add(queryOperation)
    }
    
    private func fetchMonthlyNotesInZone(zoneID: CKRecordZone.ID, completion: @escaping ([SharedMonthlyNotesRecord]) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "CD_MonthlyNotes", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "CD_year", ascending: true), NSSortDescriptor(key: "CD_month", ascending: true)]
        
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        queryOperation.resultsLimit = 100
        
        var monthlyNotes: [SharedMonthlyNotesRecord] = []
        
        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                let monthlyNote = SharedMonthlyNotesRecord(from: record)
                monthlyNotes.append(monthlyNote)
                debugLog("📝 Monthly Note: \(monthlyNote.month)/\(monthlyNote.year) - \(monthlyNote.line1 ?? "nil")")
            case .failure(let error):
                debugLog("❌ Failed to fetch monthly note \(recordID): \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cursor):
                    if cursor != nil {
                        // Handle pagination if needed
                        debugLog("📄 More monthly notes available, but we'll get them in next fetch")
                    }
                    completion(monthlyNotes)
                case .failure(let error):
                    debugLog("❌ Monthly notes query failed for zone \(zoneID.zoneName): \(error)")
                    completion(monthlyNotes)
                }
            }
        }
        
        self.sharedDatabase.add(queryOperation)
    }
}

// MARK: - Data Models
struct SharedScheduleRecord: Identifiable, Equatable, Hashable {
    let id: String
    let date: Date?
    let line1: String?
    let line2: String?
    let line3: String?
    let zoneID: CKRecordZone.ID
    
    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.date = record["CD_date"] as? Date
        self.line1 = record["CD_line1"] as? String
        self.line2 = record["CD_line2"] as? String
        self.line3 = record["CD_line3"] as? String
        self.zoneID = record.recordID.zoneID
    }
}

struct SharedMonthlyNotesRecord: Identifiable, Equatable, Hashable {
    let id: String
    let month: Int
    let year: Int
    let line1: String?
    let line2: String?
    let line3: String?
    let zoneID: CKRecordZone.ID
    
    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.month = record["CD_month"] as? Int ?? 0
        self.year = record["CD_year"] as? Int ?? 0
        self.line1 = record["CD_line1"] as? String
        self.line2 = record["CD_line2"] as? String
        self.line3 = record["CD_line3"] as? String
        self.zoneID = record.recordID.zoneID
    }
}
