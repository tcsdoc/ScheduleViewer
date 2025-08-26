//
//  ScheduleView.swift
//  ScheduleViewer
//
//  Created by mark on 7/12/25.
//

import SwiftUI
import CloudKit
import UIKit

struct ScheduleView: View {
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var currentMonth = Date()
    @State private var showShareURLInput = false
    @State private var shareURLText = ""
    @State private var shareStatus = ""
    @State private var showShareStatus = false
    
    var body: some View {
        Group {
            if cloudKitManager.isLoading {
                ProgressView("Loading schedule data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if horizontalSizeClass == .compact {
                    NavigationView {
                        iPhoneScheduleListView(
                            dailySchedules: cloudKitManager.dailySchedules,
                            monthlyNotes: cloudKitManager.monthlyNotes,
                            currentMonth: $currentMonth
                        )
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Debug") {
                                    Task {
                                        await cloudKitManager.checkForAcceptedShares()
                                    }
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu("Actions") {
                                    Button("Refresh") {
                                        Task {
                                            await cloudKitManager.fetchAllData()
                                        }
                                    }
                                    Button("Accept Share") {
                                        showShareURLInput = true
                                    }
                                }
                            }
                        }
                    }
                } else {
                    iPadCalendarGridView(
                        dailySchedules: cloudKitManager.dailySchedules,
                        monthlyNotes: cloudKitManager.monthlyNotes,
                        currentMonth: $currentMonth
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Debug") {
                                Task {
                                    await cloudKitManager.checkForAcceptedShares()
                                }
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu("Actions") {
                                Button("Refresh") {
                                    Task {
                                        await cloudKitManager.fetchAllData()
                                    }
                                }
                                Button("Accept Share") {
                                    showShareURLInput = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            #if DEBUG
            print("🔄 ScheduleViewer appeared - fetching data...")
            #endif
            Task {
                await cloudKitManager.fetchAllData()
                await cloudKitManager.checkForAcceptedShares()
            }
        }
        .refreshable {
            #if DEBUG
            print("🔄 Manual refresh triggered in ScheduleViewer")
            #endif
            await cloudKitManager.fetchAllData()
            await cloudKitManager.checkForAcceptedShares()
        }
        .alert("Enter Share URL", isPresented: $showShareURLInput) {
            TextField("Paste CloudKit share URL here", text: $shareURLText)
            Button("Accept") {
                #if DEBUG
                print("🔗 User tapped Accept button with text: '\(shareURLText)'")
                #endif
                let trimmedURL = shareURLText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: trimmedURL) {
                    #if DEBUG
                    print("🔗 Successfully created URL from text: '\(trimmedURL)'")
                    print("🔗 URL components - Host: \(url.host ?? "nil"), Path: \(url.path)")
                    print("🔗 Calling acceptShare...")
                    #endif
                    shareStatus = "Processing share..."
                    showShareStatus = true
                    cloudKitManager.acceptShare(from: url)
                    shareURLText = ""
                } else {
                    #if DEBUG
                    print("❌ Failed to create URL from text: '\(trimmedURL)'")
                    print("❌ Original text: '\(shareURLText)'")
                    #endif
                    shareStatus = "Could not parse URL. Please check the format."
                    showShareStatus = true
                }
            }
            Button("Cancel", role: .cancel) {
                shareURLText = ""
            }
        }
        .alert("Share Status", isPresented: $showShareStatus) {
            Button("OK") { shareStatus = "" }
        } message: {
            Text(shareStatus)
        }
    }
}

// MARK: - iPhone List View
struct iPhoneScheduleListView: View {
    let dailySchedules: [DailyScheduleRecord]
    let monthlyNotes: [MonthlyNotesRecord]
    @Binding var currentMonth: Date
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Month Navigation with Print Button
            HStack {
                Button(action: { currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth }) {
                    Image(systemName: "chevron.left").font(.title2)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(monthYearString(from: currentMonth))
                        .font(.title2)
                        .fontWeight(.semibold)
                    if cloudKitManager.hasSharedData {
                        Text("📡 Shared Data")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                Spacer()
                
                // Print Button
                Button(action: { printCalendar(dailySchedules: dailySchedules, monthlyNotes: monthlyNotes, currentMonth: currentMonth) }) {
                    Image(systemName: "printer")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 8)
                
                Button(action: { currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth }) {
                    Image(systemName: "chevron.right").font(.title2)
                }
            }.padding(.horizontal)
            
            // Monthly Notes
            if let note = monthlyNotes.first(where: { $0.month == Calendar.current.component(.month, from: currentMonth) && $0.year == Calendar.current.component(.year, from: currentMonth) }),
               !(note.line1 ?? "").isEmpty || !(note.line2 ?? "").isEmpty || !(note.line3 ?? "").isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Notes")
                        .font(.headline)
                        .padding(.bottom, 2)
                    if let l1 = note.line1, !l1.isEmpty { Text("• \(l1)").foregroundColor(.blue) }
                    if let l2 = note.line2, !l2.isEmpty { Text("• \(l2)").foregroundColor(.green) }
                    if let l3 = note.line3, !l3.isEmpty { Text("• \(l3)").foregroundColor(.orange) }
                }.padding(.horizontal)
            }
            
            // Schedule List
            ScrollView {
                LazyVStack(spacing: 10) {
                    Text("Schedule").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                    ForEach(daysInMonth(currentMonth), id: \.self) { date in
                        let schedule = dailySchedules.first(where: { 
                            Calendar.current.isDate($0.date, inSameDayAs: date)
                        })
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(dayString(from: date)).font(.headline)
                                Spacer()
                                Text(weekdayString(from: date)).font(.caption).foregroundColor(.gray)
                            }
                            if let s = schedule {
                                if let l1 = s.line1, !l1.isEmpty { Text("OS: \(l1)").foregroundColor(.blue) }
                                if let l2 = s.line2, !l2.isEmpty { Text("CL: \(l2)").foregroundColor(.green) }
                                if let l3 = s.line3, !l3.isEmpty { Text("OFF: \(l3)").foregroundColor(.orange) }
                            } else {
                                Text("No schedule").italic().foregroundColor(.gray)
                            }
                        }.padding().background(Color(.systemBackground)).cornerRadius(8).shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
                    }
                }.padding(.horizontal)
            }
        }.padding(.top, 8)
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func daysInMonth(_ date: Date) -> [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        return range.compactMap { day in calendar.date(byAdding: .day, value: day - 1, to: firstDay) }
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func weekdayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - iPad Calendar Grid View
struct iPadCalendarGridView: View {
    let dailySchedules: [DailyScheduleRecord]
    let monthlyNotes: [MonthlyNotesRecord]
    @Binding var currentMonth: Date
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    // Month Navigation
                    HStack {
                        Button(action: { currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth }) {
                            Image(systemName: "chevron.left").font(.title2)
                        }
                        Spacer()
                        Text(monthYearString(from: currentMonth))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        
                        // Print Button
                        Button(action: { printCalendar(dailySchedules: dailySchedules, monthlyNotes: monthlyNotes, currentMonth: currentMonth) }) {
                            Image(systemName: "printer")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .padding(.trailing, 105)
                        
                        Button(action: { currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth }) {
                            Image(systemName: "chevron.right").font(.title2)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Monthly Notes
                    if let note = monthlyNotes.first(where: { $0.month == Calendar.current.component(.month, from: currentMonth) && $0.year == Calendar.current.component(.year, from: currentMonth) }),
                       !(note.line1 ?? "").isEmpty || !(note.line2 ?? "").isEmpty || !(note.line3 ?? "").isEmpty {
                        VStack(spacing: 8) {
                            Text("Monthly Notes")
                                .font(.title2)
                                .fontWeight(.semibold)
                            VStack(spacing: 6) {
                                if let l1 = note.line1, !l1.isEmpty { 
                                    Text(l1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                        .font(.body)
                                }
                                if let l2 = note.line2, !l2.isEmpty { 
                                    Text(l2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(6)
                                        .font(.body)
                                }
                                if let l3 = note.line3, !l3.isEmpty { 
                                    Text(l3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(6)
                                        .font(.body)
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // Calendar Grid
                    VStack(spacing: 8) {
                        // Day headers
                        HStack(spacing: 0) {
                            ForEach(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                                Text(day)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // Calendar days
                        let days = daysInMonth(currentMonth)
                        let chunkedDays = days.chunked(into: 7)
                        
                        ForEach(0..<chunkedDays.count, id: \.self) { weekIndex in
                            HStack(spacing: 0) {
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    if weekIndex * 7 + dayIndex < days.count {
                                        let date = days[weekIndex * 7 + dayIndex]
                                        let schedule = dailySchedules.first(where: { 
                                            Calendar.current.isDate($0.date, inSameDayAs: date)
                                        })
                                        
                                        VStack(spacing: 4) {
                                            Text("\(Calendar.current.component(.day, from: date))")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .padding(.bottom, 4)
                                            
                                            if let s = schedule {
                                                if let l1 = s.line1, !l1.isEmpty { 
                                                    Text(l1)
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                        .lineLimit(1)
                                                        .padding(.horizontal, 2)
                                                }
                                                if let l2 = s.line2, !l2.isEmpty { 
                                                    Text(l2)
                                                        .font(.caption)
                                                        .foregroundColor(.green)
                                                        .lineLimit(1)
                                                        .padding(.horizontal, 2)
                                                }
                                                if let l3 = s.line3, !l3.isEmpty { 
                                                    Text(l3)
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                        .lineLimit(1)
                                                        .padding(.horizontal, 2)
                                                }
                                            } else {
                                                Text("No schedule")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                                    .italic()
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 120)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                    } else {
                                        Spacer()
                                            .frame(maxWidth: .infinity, minHeight: 120)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func daysInMonth(_ date: Date) -> [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        return range.compactMap { day in calendar.date(byAdding: .day, value: day - 1, to: firstDay) }
    }
    

    

}

// MARK: - Shared Print Functions
func printCalendar(dailySchedules: [DailyScheduleRecord], monthlyNotes: [MonthlyNotesRecord], currentMonth: Date) {
    // Create a printable version of the calendar
    let printController = UIPrintInteractionController.shared
    
    let printInfo = UIPrintInfo(dictionary: nil)
    printInfo.outputType = .general
    printInfo.jobName = "Schedule - \(monthYearString(from: currentMonth))"
    printController.printInfo = printInfo
    
    // Create HTML content for printing
    let htmlContent = generatePrintHTML(dailySchedules: dailySchedules, monthlyNotes: monthlyNotes, currentMonth: currentMonth)
    let formatter = UIMarkupTextPrintFormatter(markupText: htmlContent)
    formatter.perPageContentInsets = UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30)
    printController.printFormatter = formatter
    
    // Present print dialog
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first,
       let _ = window.rootViewController {
        printController.present(animated: true, completionHandler: nil)
    }
}

func generatePrintHTML(dailySchedules: [DailyScheduleRecord], monthlyNotes: [MonthlyNotesRecord], currentMonth: Date) -> String {
    let monthYear = monthYearString(from: currentMonth)
    
    var html = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 20px; font-size: 12px; }
            .header { text-align: center; font-size: 24px; font-weight: bold; margin-bottom: 20px; }
            .monthly-notes { margin-bottom: 20px; }
            .monthly-notes h3 { font-size: 16px; margin-bottom: 10px; color: #333; }
            .note-item { margin: 5px 0; padding: 8px; border-radius: 4px; font-size: 12px; }
            .note-blue { background-color: rgba(0, 122, 255, 0.15); border-left: 4px solid #007AFF; }
            .note-green { background-color: rgba(52, 199, 89, 0.15); border-left: 4px solid #34C759; }
            .note-orange { background-color: rgba(255, 149, 0, 0.15); border-left: 4px solid #FF9500; }
            table { width: 100%; border-collapse: collapse; margin-top: 10px; }
            th { background-color: #f8f8f8; padding: 8px; text-align: center; font-weight: bold; border: 1px solid #ddd; font-size: 13px; }
            td { border: 1px solid #ddd; padding: 6px; vertical-align: top; height: 90px; width: 14.28%; }
            .day-number { font-weight: bold; font-size: 14px; margin-bottom: 4px; color: #333; }
            .schedule-line { font-size: 9px; margin: 2px 0; line-height: 1.3; }
            .line-blue { color: #007AFF; font-weight: 500; }
            .line-green { color: #34C759; font-weight: 500; }
            .line-orange { color: #FF9500; font-weight: 500; }
            .no-schedule { font-style: italic; color: #999; font-size: 9px; }
            .weekend { background-color: #f9f9f9; }
        </style>
    </head>
    <body>
        <div class="header">\(monthYear)</div>
    """
    
    // Add monthly notes if they exist
    if let note = monthlyNotes.first(where: { $0.month == Calendar.current.component(.month, from: currentMonth) && $0.year == Calendar.current.component(.year, from: currentMonth) }),
       !(note.line1 ?? "").isEmpty || !(note.line2 ?? "").isEmpty || !(note.line3 ?? "").isEmpty {
        html += """
        <div class="monthly-notes">
            <h3>Monthly Notes</h3>
        """
        if let l1 = note.line1, !l1.isEmpty {
            html += "<div class=\"note-item note-blue\">\(l1)</div>"
        }
        if let l2 = note.line2, !l2.isEmpty {
            html += "<div class=\"note-item note-green\">\(l2)</div>"
        }
        if let l3 = note.line3, !l3.isEmpty {
            html += "<div class=\"note-item note-orange\">\(l3)</div>"
        }
        html += "</div>"
    }
    
    // Add calendar table with proper grid layout
    html += """
        <table>
            <tr>
                <th>Sunday</th>
                <th>Monday</th>
                <th>Tuesday</th>
                <th>Wednesday</th>
                <th>Thursday</th>
                <th>Friday</th>
                <th>Saturday</th>
            </tr>
    """
    
    // Get first day of month and calculate starting position
    let calendar = Calendar.current
    let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
    let startWeekday = calendar.component(.weekday, from: firstDayOfMonth) // 1 = Sunday
    let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!.count
    
    var dayCounter = 1
    var weekRow = 0
    
    // Create calendar rows
    while dayCounter <= daysInMonth {
        html += "<tr>"
        
        for dayOfWeek in 1...7 { // 1 = Sunday, 7 = Saturday
            let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
            let weekendClass = isWeekend ? " weekend" : ""
            
            if (weekRow == 0 && dayOfWeek < startWeekday) || dayCounter > daysInMonth {
                // Empty cell for days before month starts or after month ends
                html += "<td class=\"\(weekendClass)\"></td>"
            } else {
                // Day with schedule data
                let dayDate = calendar.date(byAdding: .day, value: dayCounter - 1, to: firstDayOfMonth)!
                let schedule = dailySchedules.first(where: { 
                    calendar.isDate($0.date, inSameDayAs: dayDate)
                })
                
                html += "<td class=\"\(weekendClass)\">"
                html += "<div class=\"day-number\">\(dayCounter)</div>"
                
                if let s = schedule {
                    if let l1 = s.line1, !l1.isEmpty {
                        html += "<div class=\"schedule-line line-blue\">OS: \(l1)</div>"
                    }
                    if let l2 = s.line2, !l2.isEmpty {
                        html += "<div class=\"schedule-line line-green\">CL: \(l2)</div>"
                    }
                    if let l3 = s.line3, !l3.isEmpty {
                        html += "<div class=\"schedule-line line-orange\">OFF: \(l3)</div>"
                    }
                } else {
                    html += "<div class=\"no-schedule\">No schedule</div>"
                }
                html += "</td>"
                dayCounter += 1
            }
        }
        
        html += "</tr>"
        weekRow += 1
        
        // Safety check to prevent infinite loop
        if weekRow > 6 { break }
    }
    
    html += """
        </table>
    </body>
    </html>
    """
    
    return html
}

// Helper functions for print functionality
func monthYearString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: date)
}

func daysInMonth(_ date: Date) -> [Date] {
    let calendar = Calendar.current
    let range = calendar.range(of: .day, in: .month, for: date)!
    let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    return range.compactMap { day in calendar.date(byAdding: .day, value: day - 1, to: firstDay) }
}

// Helper extension for chunking arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 