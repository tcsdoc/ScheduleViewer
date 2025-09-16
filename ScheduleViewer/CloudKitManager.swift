import Foundation
import CloudKit
import SwiftUI

// MARK: - Debug Logging Helper
func debugLog(_ message: String) {
    // Temporarily enabled for Production debugging of deletion issue
    print("SV DEBUG: \(message)")
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
    }
    
    private func loadAcceptedSharedZonesFromDefaults() {
        guard let zoneData = UserDefaults.standard.array(forKey: "acceptedSharedZones") as? [[String: String]] else {
            return
        }
        
        acceptedSharedZones = zoneData.compactMap { dict in
            guard let zoneName = dict["zoneName"],
                  let ownerName = dict["ownerName"] else { return nil }
            return CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        }
        
        // If we have persisted zones, we should automatically fetch data
        if !acceptedSharedZones.isEmpty {
            fetchSharedSchedules()
        }
    }
    
    private func clearAcceptedSharedZones() {
        acceptedSharedZones = []
        UserDefaults.standard.removeObject(forKey: "acceptedSharedZones")
    }
    
    // MARK: - CloudKit Account Status
    private func checkCloudKitStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.cloudKitAvailable = true
                    self?.errorMessage = nil
                case .noAccount:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "Please sign in to iCloud to view shared schedules."
                case .restricted:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "iCloud access is restricted."
                case .couldNotDetermine:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "Unable to determine iCloud status."
                case .temporarilyUnavailable:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "iCloud is temporarily unavailable."
                @unknown default:
                    self?.cloudKitAvailable = false
                    self?.errorMessage = "Unknown iCloud status."
                }
            }
        }
    }
    
    // MARK: - Share Management
    func checkForSharedData() {
        guard cloudKitAvailable else {
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
        Task {
            do {
                let sharedZones = try await sharedDatabase.allRecordZones()
                
                DispatchQueue.main.async {
                    self.acceptedSharedZones = sharedZones.map { $0.zoneID }
                    completion()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to discover shared data: \(error.localizedDescription)"
                    completion()
                }
            }
        }
    }
    
    private func fetchSharedSchedules() {
        guard !acceptedSharedZones.isEmpty else {
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
            
            fetchRecordsInZone(zoneID: zoneID, cursor: nil) { zoneRecords in
                self.processZoneRecords(zoneRecords, from: zoneID, into: &allSchedules)
                
                // Only check private database if this is OUR zone
                if zoneID.ownerName == CKCurrentUserDefaultName {
                    group.enter()
                    self.queryPrivateDatabase(zoneID: zoneID) { privateSchedules in
                        allSchedules.append(contentsOf: privateSchedules)
                        group.leave()
                    }
                }
                group.leave()
            }
        }
        
        // Query each shared zone for monthly notes
        for zoneID in acceptedSharedZones {
            group.enter()
            
            fetchMonthlyNotesInZone(zoneID: zoneID) { zoneNotes in
                allMonthlyNotes.append(contentsOf: zoneNotes)
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            // Remove duplicates by date (multiple records for same date should show only the latest)
            let uniqueSchedules = Dictionary(grouping: allSchedules, by: { 
                // Group by date (day level) instead of record ID
                guard let date = $0.date else { return "no-date-\($0.id)" }
                let calendar = Calendar.current
                let dayStart = calendar.startOfDay(for: date)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: dayStart)
            })
                .values
                .compactMap { records in
                    // For each date, keep the most recent record (by creation/modification)
                    return records.max { record1, record2 in
                        // Prefer records with more complete data (more non-empty fields)
                        let count1 = [record1.line1, record1.line2, record1.line3].compactMap { $0 }.filter { !$0.isEmpty }.count
                        let count2 = [record2.line1, record2.line2, record2.line3].compactMap { $0 }.filter { !$0.isEmpty }.count
                        return count1 < count2
                    }
                }
                .sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
            
            let uniqueMonthlyNotes = Dictionary(grouping: allMonthlyNotes, by: { $0.id })
                .values
                .compactMap { $0.first }
                .sorted { ($0.year * 100 + $0.month) < ($1.year * 100 + $1.month) }
            
            self?.sharedSchedules = uniqueSchedules
            self?.sharedMonthlyNotes = uniqueMonthlyNotes
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
        
        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                zoneRecords.append(record)
            case .failure(let error):
                debugLog("Failed to process record \(recordID): \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        self.fetchRecordsInZone(zoneID: zoneID, cursor: cursor) { additionalRecords in
                            completion(zoneRecords + additionalRecords)
                        }
                    } else {
                        completion(zoneRecords)
                    }
                case .failure(let error):
                    debugLog("Query failed for zone \(zoneID.zoneName): \(error)")
                    completion(zoneRecords)
                }
            }
        }
        
        sharedDatabase.add(queryOperation)
    }
    
    private func processZoneRecords(_ records: [CKRecord], from zoneID: CKRecordZone.ID, into allSchedules: inout [SharedScheduleRecord]) {
        let schedules = records.map(SharedScheduleRecord.init)
        allSchedules.append(contentsOf: schedules)
    }
    
    // MARK: - Share Acceptance
    func acceptShareFromURL(_ url: URL, completion: @escaping (Bool, Error?) -> Void) {
        debugLog("🔗 SV CLOUDKIT: Starting share acceptance process")
        debugLog("🔗 SV CLOUDKIT: Share URL: \(url.absoluteString)")
        debugLog("🔗 SV CLOUDKIT: CloudKit Available: \(cloudKitAvailable)")
        
        guard cloudKitAvailable else {
            debugLog("❌ SV CLOUDKIT: CloudKit not available")
            completion(false, NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit not available"]))
            return
        }
        
        // Fetch share metadata first
        debugLog("🔗 SV CLOUDKIT: Creating CKFetchShareMetadataOperation")
        let fetchOperation = CKFetchShareMetadataOperation(shareURLs: [url])
        fetchOperation.perShareMetadataResultBlock = { shareURL, result in
            debugLog("🔗 SV CLOUDKIT: perShareMetadataResultBlock called for URL: \(shareURL.absoluteString)")
            switch result {
            case .success(let metadata):
                debugLog("✅ SV CLOUDKIT: Share metadata fetched successfully")
                debugLog("🔗 SV CLOUDKIT: Share type: \(metadata.share.recordType)")
                debugLog("🔗 SV CLOUDKIT: Root record type: \(metadata.rootRecordID.recordName)")
                debugLog("🔗 SV CLOUDKIT: Participant permission: \(metadata.participantPermission.rawValue)")
                debugLog("🔗 SV CLOUDKIT: Participant status: \(metadata.participantStatus.rawValue)")
                self.acceptShare(metadata: metadata, completion: completion)
            case .failure(let error):
                debugLog("❌ SV CLOUDKIT: Failed to fetch share metadata: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    debugLog("❌ SV CLOUDKIT: CKError code: \(ckError.code.rawValue)")
                    debugLog("❌ SV CLOUDKIT: CKError description: \(ckError.localizedDescription)")
                }
                completion(false, error)
            }
        }
        
        fetchOperation.fetchShareMetadataResultBlock = { result in
            debugLog("🔗 SV CLOUDKIT: fetchShareMetadataResultBlock called")
            switch result {
            case .success:
                debugLog("✅ SV CLOUDKIT: Overall fetch metadata operation succeeded")
                break
            case .failure(let error):
                debugLog("❌ SV CLOUDKIT: Overall fetch metadata operation failed: \(error.localizedDescription)")
                completion(false, error)
            }
        }
        
        debugLog("🔗 SV CLOUDKIT: Adding fetch operation to container")
        container.add(fetchOperation)
    }
    
    private func acceptShare(metadata: CKShare.Metadata, completion: @escaping (Bool, Error?) -> Void) {
        debugLog("🔗 SV CLOUDKIT: Creating CKAcceptSharesOperation")
        debugLog("🔗 SV CLOUDKIT: Metadata root record: \(metadata.rootRecordID.recordName)")
        
        let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        acceptOperation.perShareResultBlock = { metadata, result in
            debugLog("🔗 SV CLOUDKIT: perShareResultBlock called")
            switch result {
            case .success(let share):
                debugLog("✅ SV CLOUDKIT: Share accepted successfully!")
                debugLog("🔗 SV CLOUDKIT: Share URL: \(share.url?.absoluteString ?? "nil")")
                debugLog("🔗 SV CLOUDKIT: Share record ID: \(share.recordID)")
                debugLog("🔗 SV CLOUDKIT: Share participants: \(share.participants.count)")
                
                DispatchQueue.main.async { [weak self] in
                    self?.acceptedShares.append(share)
                    debugLog("🔗 SV CLOUDKIT: Added share to acceptedShares array")
                    
                    // Immediately discover and persist the new shared zones
                    debugLog("🔗 SV CLOUDKIT: Starting zone discovery after share acceptance")
                    self?.discoverSharedZones {
                        debugLog("✅ SV CLOUDKIT: Zone discovery completed after share acceptance")
                    }
                    completion(true, nil)
                }
            case .failure(let error):
                debugLog("❌ SV CLOUDKIT: Failed to accept share: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    debugLog("❌ SV CLOUDKIT: Accept share CKError code: \(ckError.code.rawValue)")
                    debugLog("❌ SV CLOUDKIT: Accept share CKError description: \(ckError.localizedDescription)")
                }
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
        
        acceptOperation.acceptSharesResultBlock = { result in
            debugLog("🔗 SV CLOUDKIT: acceptSharesResultBlock called")
            switch result {
            case .success:
                debugLog("✅ SV CLOUDKIT: Overall accept shares operation succeeded")
                break
            case .failure(let error):
                debugLog("❌ SV CLOUDKIT: Overall accept shares operation failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
        
        debugLog("🔗 SV CLOUDKIT: Adding accept operation to container")
        container.add(acceptOperation)
    }
    
    func refreshAfterShareAcceptance() {
        checkForSharedData()
    }
    
    /// Force refresh data from existing shared zones (for manual refresh)
    func forceRefreshSharedData() {
        guard cloudKitAvailable else {
            debugLog("❌ SV REFRESH: CloudKit not available")
            return
        }
        
        debugLog("🔄 SV REFRESH: Force refreshing shared data from existing zones")
        
        // Skip zone discovery, directly fetch fresh data from known zones
        fetchSharedSchedules()
    }
    
    private func queryPrivateDatabase(zoneID: CKRecordZone.ID, completion: @escaping ([SharedScheduleRecord]) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "CD_DailySchedule", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
        
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        queryOperation.resultsLimit = 100
        
        var privateRecords: [CKRecord] = []
        
        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                privateRecords.append(record)
            case .failure(let error):
                debugLog("Failed to process private record \(recordID): \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    let schedules = privateRecords.map(SharedScheduleRecord.init)
                    completion(schedules)
                case .failure(let error):
                    debugLog("Private DB query failed for zone \(zoneID.zoneName): \(error)")
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
            case .failure(let error):
                debugLog("Failed to fetch monthly note \(recordID): \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cursor):
                    if cursor != nil {
                        // Handle pagination if needed in future
                    }
                    completion(monthlyNotes)
                case .failure(let error):
                    debugLog("Monthly notes query failed for zone \(zoneID.zoneName): \(error)")
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
