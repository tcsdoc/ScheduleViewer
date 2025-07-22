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
        privateDatabase = container.privateCloudDatabase  // Changed from public to private
        print("✅ ScheduleViewer configured for Private Database")
    }
    
    func fetchAllData() {
        isLoading = true
        
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
            self.isLoading = false
        }
    }
    
    private func fetchDailySchedules(completion: @escaping () -> Void) {
        let query = CKQuery(recordType: "CD_DailySchedule", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
        
        Task {
            do {
                let (records, _) = try await privateDatabase.records(matching: query)
                let scheduleRecords = records.compactMap { _, result in
                    try? result.get()
                }.compactMap { record in
                    DailyScheduleRecord(from: record)
                }
                
                await MainActor.run {
                    print("✅ Fetched \(scheduleRecords.count) daily schedules from Private Database")
                    self.dailySchedules = scheduleRecords
                    completion()
                }
            } catch {
                await MainActor.run {
                    print("❌ Error fetching daily schedules from Private Database: \(error)")
                    completion()
                }
            }
        }
    }
    
    private func fetchMonthlyNotes(completion: @escaping () -> Void) {
        let query = CKQuery(recordType: "CD_MonthlyNotes", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "CD_month", ascending: true)]
        
        Task {
            do {
                let (records, _) = try await privateDatabase.records(matching: query)
                let notesRecords = records.compactMap { _, result in
                    try? result.get()
                }.compactMap { record in
                    MonthlyNotesRecord(from: record)
                }
                
                await MainActor.run {
                    print("✅ Fetched \(notesRecords.count) monthly notes from Private Database")
                    self.monthlyNotes = notesRecords
                    completion()
                }
            } catch {
                await MainActor.run {
                    print("❌ Error fetching monthly notes from Private Database: \(error)")
                    completion()
                }
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
