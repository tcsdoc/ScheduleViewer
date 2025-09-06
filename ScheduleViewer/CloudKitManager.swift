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
        guard cloudKitAvailable else {
            completion(false, NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit not available"]))
            return
        }
        
        // Fetch share metadata first
        let fetchOperation = CKFetchShareMetadataOperation(shareURLs: [url])
        fetchOperation.perShareMetadataResultBlock = { shareURL, result in
            switch result {
            case .success(let metadata):
                self.acceptShare(metadata: metadata, completion: completion)
            case .failure(let error):
                completion(false, error)
            }
        }
        
        fetchOperation.fetchShareMetadataResultBlock = { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                completion(false, error)
            }
        }
        
        container.add(fetchOperation)
    }
    
    private func acceptShare(metadata: CKShare.Metadata, completion: @escaping (Bool, Error?) -> Void) {
        let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        acceptOperation.perShareResultBlock = { metadata, result in
            switch result {
            case .success(let share):
                DispatchQueue.main.async { [weak self] in
                    self?.acceptedShares.append(share)
                    // Immediately discover and persist the new shared zones
                    self?.discoverSharedZones {
                        // Zone discovery completed
                    }
                    completion(true, nil)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
        
        acceptOperation.acceptSharesResultBlock = { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
        
        container.add(acceptOperation)
    }
    
    func refreshAfterShareAcceptance() {
        checkForSharedData()
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
