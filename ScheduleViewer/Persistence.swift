//
//  Persistence.swift
//  ScheduleViewer
//
//  Created by mark on 7/5/25.
//

import Foundation
import CloudKit

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    
    @Published var dailySchedules: [DailyScheduleRecord] = []
    @Published var monthlyNotes: [MonthlyNotesRecord] = []
    @Published var isLoading = false
    
    init() {
        container = CKContainer(identifier: "iCloud.com.gulfcoast.ProviderCalendar")
        publicDatabase = container.publicCloudDatabase
    }
    
    func fetchAllData() {
        isLoading = true
        
        let group = DispatchGroup()
        
        // Fetch Daily Schedules
        group.enter()
        fetchDailySchedules { [weak self] in
            group.leave()
        }
        
        // Fetch Monthly Notes
        group.enter()
        fetchMonthlyNotes { [weak self] in
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func fetchDailySchedules(completion: @escaping () -> Void) {
        let query = CKQuery(recordType: "CD_DailySchedule", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "CD_date", ascending: true)]
        
        publicDatabase.perform(query, inZoneWith: nil) { [weak self] records, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching daily schedules: \(error)")
                } else if let records = records {
                    self?.dailySchedules = records.compactMap { record in
                        DailyScheduleRecord(from: record)
                    }
                }
                completion()
            }
        }
    }
    
    private func fetchMonthlyNotes(completion: @escaping () -> Void) {
        let query = CKQuery(recordType: "CD_MonthlyNotes", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "CD_month", ascending: true)]
        
        publicDatabase.perform(query, inZoneWith: nil) { [weak self] records, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching monthly notes: \(error)")
                } else if let records = records {
                    self?.monthlyNotes = records.compactMap { record in
                        MonthlyNotesRecord(from: record)
                    }
                }
                completion()
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
        self.month = (record["CD_month"] as? Int) ?? 0
        self.year = (record["CD_year"] as? Int) ?? 0
        self.line1 = record["CD_line1"] as? String
        self.line2 = record["CD_line2"] as? String
        self.line3 = record["CD_line3"] as? String
    }
}
