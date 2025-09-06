import SwiftUI
import CloudKit
import UIKit

struct ContentView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @State private var selectedDate = Date()
    @State private var shareURL: String = ""
    @State private var showingShareInput = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with CloudKit status
                    headerSection
                    
                    // Share input section
                    shareInputSection
                    
                    // Schedule display
                    scheduleSection
                    
                    // Monthly notes display
                    monthlyNotesSection
                }
                .padding()
            }
            .navigationTitle("Schedule Viewer")
            .onAppear {
                cloudKitManager.checkForSharedData()
            }
            .sheet(isPresented: $showingShareInput) {
                shareInputSheet
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("📱 Schedule Viewer")
                .font(.title2)
                .fontWeight(.bold)
            
            if cloudKitManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading shared schedules...")
                }
                .foregroundColor(.blue)
            } else if !cloudKitManager.cloudKitAvailable {
                Text("⚠️ CloudKit not available")
                    .foregroundColor(.orange)
            } else if cloudKitManager.sharedSchedules.isEmpty && cloudKitManager.sharedMonthlyNotes.isEmpty {
                Text("📭 No shared data found")
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        VStack(spacing: 2) {
                            Text("✅ \(cloudKitManager.sharedSchedules.count) schedules")
                                .foregroundColor(.green)
                            Text("✅ \(cloudKitManager.sharedMonthlyNotes.count) monthly notes")
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                        
                        Spacer()
                        
                        Button(action: {
                            printCalendar()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "printer")
                                Text("Print")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var shareInputSection: some View {
        VStack(spacing: 12) {
            // Only show "Add Share" section if no data is available
            if cloudKitManager.sharedSchedules.isEmpty && cloudKitManager.sharedMonthlyNotes.isEmpty && !cloudKitManager.isLoading {
                HStack {
                    Text("📤 Initial Setup Required")
                        .font(.headline)
                    Spacer()
                    Button("Add Share") {
                        showingShareInput = true
                    }
                    .foregroundColor(.blue)
                }
                
                Text("Tap 'Add Share' to connect to a Provider Schedule Calendar")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else if !cloudKitManager.sharedSchedules.isEmpty || !cloudKitManager.sharedMonthlyNotes.isEmpty {
                // Show clean status when data is available
                HStack {
                    Text("📤 Connected to Provider Schedule")
                        .font(.headline)
                        .foregroundColor(.green)
                    Spacer()
                    Text("✅")
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedules")
                .font(.headline)
            
            if cloudKitManager.sharedSchedules.isEmpty {
                Text("No schedules available")
                    .foregroundColor(.gray)
                    .italic()
            } else {
                ForEach(cloudKitManager.sharedSchedules) { schedule in
                    ScheduleRowView(schedule: schedule)
                }
            }
        }
    }
    
    private var monthlyNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Notes")
                .font(.headline)
            
            if cloudKitManager.sharedMonthlyNotes.isEmpty {
                Text("No monthly notes available")
                    .foregroundColor(.gray)
                    .italic()
            } else {
                ForEach(cloudKitManager.sharedMonthlyNotes) { note in
                    MonthlyNoteRowView(note: note)
                }
            }
        }
    }
    
    private var shareInputSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Connect to Provider Schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This is a one-time setup. Paste the share URL from Provider Schedule Calendar:")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                TextField("https://www.icloud.com/share/...", text: $shareURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Accept Share") {
                    acceptShare()
                }
                .disabled(shareURL.isEmpty)
                .foregroundColor(.white)
                .padding()
                .background(shareURL.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Share")
            .navigationBarItems(trailing: Button("Cancel") {
                showingShareInput = false
                shareURL = ""
            })
        }
    }
    
    private func acceptShare() {
        guard let url = URL(string: shareURL) else {
            debugLog("❌ Invalid URL: \(shareURL)")
            return
        }
        
        debugLog("🔗 Attempting to accept share: \(url)")
        cloudKitManager.acceptShareFromURL(url) { success, error in
            DispatchQueue.main.async {
                if success {
                    debugLog("✅ Share accepted successfully")
                    showingShareInput = false
                    shareURL = ""
                    cloudKitManager.checkForSharedData()
                } else {
                    debugLog("❌ Failed to accept share: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    // MARK: - Print Functions
    private func printCalendar() {
        let printableView = PrintableCalendarView(
            schedules: cloudKitManager.sharedSchedules,
            monthlyNotes: cloudKitManager.sharedMonthlyNotes
        )
        
        let hostingController = UIHostingController(rootView: printableView)
        hostingController.view.backgroundColor = UIColor.white
        
        // Create a printable view with proper sizing
        let targetSize = CGSize(width: 612, height: 792) // 8.5 x 11 inches at 72 DPI
        hostingController.view.frame = CGRect(origin: .zero, size: targetSize)
        hostingController.view.layoutIfNeeded()
        
        // Present print interface
        let printController = UIPrintInteractionController.shared
        printController.printingItem = hostingController.view.renderedImage()
        
        printController.present(animated: true) { controller, completed, error in
            if let error = error {
                debugLog("❌ Print error: \(error.localizedDescription)")
            } else if completed {
                debugLog("✅ Print completed successfully")
            } else {
                debugLog("🔄 Print cancelled by user")
            }
        }
    }
}

// MARK: - UIView Extension for Rendering
extension UIView {
    func renderedImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        return renderer.image { context in
            layer.render(in: context.cgContext)
        }
    }
}

struct ScheduleRowView: View {
    let schedule: SharedScheduleRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(schedule.date))
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                if let line1 = schedule.line1, !line1.isEmpty {
                    Text("1: \(line1)")
                        .font(.body)
                }
                if let line2 = schedule.line2, !line2.isEmpty {
                    Text("2: \(line2)")
                        .font(.body)
                }
                if let line3 = schedule.line3, !line3.isEmpty {
                    Text("3: \(line3)")
                        .font(.body)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct MonthlyNoteRowView: View {
    let note: SharedMonthlyNotesRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatMonthYear(note.month, note.year))
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                if let line1 = note.line1, !line1.isEmpty {
                    Text("1: \(line1)")
                        .font(.body)
                }
                if let line2 = note.line2, !line2.isEmpty {
                    Text("2: \(line2)")
                        .font(.body)
                }
                if let line3 = note.line3, !line3.isEmpty {
                    Text("3: \(line3)")
                        .font(.body)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatMonthYear(_ month: Int, _ year: Int) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        
        // Create a date for the first day of the month
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let date = Calendar.current.date(from: components) else {
            return "\(month)/\(year)"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Printable Calendar View
struct PrintableCalendarView: View {
    let schedules: [SharedScheduleRecord]
    let monthlyNotes: [SharedMonthlyNotesRecord]
    
    private let calendar = Calendar.current
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("PROVIDER SCHEDULE")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                // Generate months to show (current + next 11 months)
                ForEach(monthsToShow, id: \.self) { month in
                    PrintableMonthView(
                        month: month,
                        schedules: schedules,
                        monthlyNotes: monthlyNotes
                    )
                }
            }
            .padding()
        }
        .background(Color.white)
    }
    
    private var monthsToShow: [Date] {
        var months: [Date] = []
        let startDate = Calendar.current.startOfMonth(for: Date())
        
        for i in 0..<12 {
            if let month = Calendar.current.date(byAdding: .month, value: i, to: startDate) {
                months.append(month)
            }
        }
        return months
    }
}

struct PrintableMonthView: View {
    let month: Date
    let schedules: [SharedScheduleRecord]
    let monthlyNotes: [SharedMonthlyNotesRecord]
    
    private let calendar = Calendar.current
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Month header
            Text(monthFormatter.string(from: month))
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Monthly notes section
            if let monthlyNote = monthlyNoteForMonth {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Notes:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let line1 = monthlyNote.line1, !line1.isEmpty {
                        Text("1: \(line1)")
                    }
                    if let line2 = monthlyNote.line2, !line2.isEmpty {
                        Text("2: \(line2)")
                    }
                    if let line3 = monthlyNote.line3, !line3.isEmpty {
                        Text("3: \(line3)")
                    }
                }
                .font(.body)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Days of week header
            HStack {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(6)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(daysInMonth, id: \.self) { date in
                    if calendar.isDate(date, equalTo: month, toGranularity: .month) {
                        PrintableDayCell(date: date, schedule: scheduleForDate(date))
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(minHeight: 80)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var monthlyNoteForMonth: SharedMonthlyNotesRecord? {
        let monthNumber = calendar.component(.month, from: month)
        let yearNumber = calendar.component(.year, from: month)
        
        return monthlyNotes.first { note in
            note.month == monthNumber && note.year == yearNumber
        }
    }
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return []
        }
        
        let startOfMonth = monthInterval.start
        guard let firstWeekday = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start else {
            return []
        }
        
        var days: [Date] = []
        var currentDate = firstWeekday
        
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
    
    private func scheduleForDate(_ date: Date) -> SharedScheduleRecord? {
        return schedules.first { schedule in
            guard let scheduleDate = schedule.date else { return false }
            return calendar.isDate(scheduleDate, inSameDayAs: date)
        }
    }
}

struct PrintableDayCell: View {
    let date: Date
    let schedule: SharedScheduleRecord?
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Day number
            HStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Schedule lines
            VStack(alignment: .leading, spacing: 1) {
                if let schedule = schedule {
                    if let line1 = schedule.line1, !line1.isEmpty {
                        Text(line1)
                            .font(.system(size: 8))
                            .lineLimit(1)
                    }
                    if let line2 = schedule.line2, !line2.isEmpty {
                        Text(line2)
                            .font(.system(size: 8))
                            .lineLimit(1)
                    }
                    if let line3 = schedule.line3, !line3.isEmpty {
                        Text(line3)
                            .font(.system(size: 8))
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(2)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Calendar Helper Extension
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    ContentView()
        .environmentObject(CloudKitManager.shared)
}
