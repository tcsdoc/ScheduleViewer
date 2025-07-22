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
                    }
                } else {
                    iPadCalendarGridView(
                        dailySchedules: cloudKitManager.dailySchedules,
                        monthlyNotes: cloudKitManager.monthlyNotes,
                        currentMonth: $currentMonth
                    )
                }
            }
        }
        .onAppear {
            print("🔄 ScheduleViewer appeared - fetching data...")
            cloudKitManager.fetchAllData()
        }
        .refreshable {
            print("🔄 Manual refresh triggered in ScheduleViewer")
            cloudKitManager.fetchAllData()
        }
    }
}

// MARK: - iPhone List View
struct iPhoneScheduleListView: View {
    let dailySchedules: [DailyScheduleRecord]
    let monthlyNotes: [MonthlyNotesRecord]
    @Binding var currentMonth: Date
    
    var body: some View {
        VStack(spacing: 12) {
            // Month Navigation
            HStack {
                Button(action: { currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth }) {
                    Image(systemName: "chevron.left").font(.title2)
                }
                Spacer()
                Text(monthYearString(from: currentMonth))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
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
                            guard let scheduleDate = $0.date else { return false }
                            return Calendar.current.isDate(scheduleDate, inSameDayAs: date)
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
                        Button(action: { printCalendar() }) {
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
                                            guard let scheduleDate = $0.date else { return false }
                                            return Calendar.current.isDate(scheduleDate, inSameDayAs: date)
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
    
    private func printCalendar() {
        // Create a printable version of the calendar
        let printController = UIPrintInteractionController.shared
        
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Schedule - \(monthYearString(from: currentMonth))"
        printController.printInfo = printInfo
        
                 // Create HTML content for printing
         let htmlContent = generatePrintHTML()
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
    
    private func generatePrintHTML() -> String {
        let monthYear = monthYearString(from: currentMonth)
        let days = daysInMonth(currentMonth)
        let chunkedDays = days.chunked(into: 7)
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
                         <style>
                 body { font-family: Arial, sans-serif; margin: 0; padding: 10px; font-size: 12px; }
                 .header { text-align: center; font-size: 20px; font-weight: bold; margin-bottom: 15px; }
                 .monthly-notes { margin-bottom: 15px; }
                 .monthly-notes h3 { font-size: 14px; margin-bottom: 8px; }
                 .note-item { margin: 3px 0; padding: 5px; border-radius: 3px; font-size: 11px; }
                 .note-blue { background-color: rgba(0, 122, 255, 0.1); }
                 .note-green { background-color: rgba(52, 199, 89, 0.1); }
                 .note-orange { background-color: rgba(255, 149, 0, 0.1); }
                 table { width: 100%; border-collapse: collapse; margin-top: 5px; }
                 th { background-color: #f5f5f5; padding: 4px; text-align: center; font-weight: bold; border: 1px solid #ddd; font-size: 11px; }
                 td { border: 1px solid #ddd; padding: 4px; vertical-align: top; height: 70px; width: 14.28%; }
                 .day-number { font-weight: bold; font-size: 11px; margin-bottom: 3px; }
                 .schedule-line { font-size: 8px; margin: 1px 0; line-height: 1.2; }
                 .line-blue { color: #007AFF; }
                 .line-green { color: #34C759; }
                 .line-orange { color: #FF9500; }
                 .no-schedule { font-style: italic; color: #999; font-size: 8px; }
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
        
        // Add calendar table
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
        
        for weekIndex in 0..<chunkedDays.count {
            html += "<tr>"
            for dayIndex in 0..<7 {
                if weekIndex * 7 + dayIndex < days.count {
                    let date = days[weekIndex * 7 + dayIndex]
                    let dayNumber = Calendar.current.component(.day, from: date)
                    let schedule = dailySchedules.first(where: { 
                        guard let scheduleDate = $0.date else { return false }
                        return Calendar.current.isDate(scheduleDate, inSameDayAs: date)
                    })
                    
                    html += "<td>"
                    html += "<div class=\"day-number\">\(dayNumber)</div>"
                    
                    if let s = schedule {
                        if let l1 = s.line1, !l1.isEmpty {
                            html += "<div class=\"schedule-line line-blue\">\(l1)</div>"
                        }
                        if let l2 = s.line2, !l2.isEmpty {
                            html += "<div class=\"schedule-line line-green\">\(l2)</div>"
                        }
                        if let l3 = s.line3, !l3.isEmpty {
                            html += "<div class=\"schedule-line line-orange\">\(l3)</div>"
                        }
                    } else {
                        html += "<div class=\"no-schedule\">No schedule</div>"
                    }
                    html += "</td>"
                } else {
                    html += "<td></td>"
                }
            }
            html += "</tr>"
        }
        
        html += """
            </table>
        </body>
        </html>
        """
        
        return html
    }
}

// Helper extension for chunking arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 