import SwiftUI
import CloudKit
import UIKit

struct ContentView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @State private var selectedDate = Date()
    @State private var shareURL: String = ""
    @State private var showingShareInput = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var currentMonthIndex = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Fixed header at top
                headerSection
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                
                // Scrollable content below
                ScrollView {
                    VStack(spacing: 20) {
                        // Share input section
                        shareInputSection
                        
                        // Monthly schedule display with notes
                        monthlyScheduleSection
                    }
                    .padding()
                }
                .refreshable {
                    cloudKitManager.forceRefreshSharedData()
                    initializeCurrentMonth()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                cloudKitManager.checkForSharedData()
                initializeCurrentMonth()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                cloudKitManager.checkForSharedData()
                initializeCurrentMonth()
            }
            .sheet(isPresented: $showingShareInput) {
                shareInputSheet
            }
            .alert("Share Error", isPresented: $showingErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Main header row: App name | Version | Print
            HStack {
                Text("📱 ScheduleViewer")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.7.5")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
            
            // Connection status row
            HStack {
                if cloudKitManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                    }
                    .foregroundColor(.blue)
                } else if !cloudKitManager.cloudKitAvailable {
                    Text("⚠️ Connection Issue")
                        .foregroundColor(.orange)
                } else if cloudKitManager.sharedSchedules.isEmpty && cloudKitManager.sharedMonthlyNotes.isEmpty {
                    Text("📭 No Data")
                        .foregroundColor(.gray)
                } else {
                    Text("✅ Connected")
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
            .font(.caption)
            
            // Month navigation row
            if !monthsWithData.isEmpty {
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }
                    .disabled(currentMonthIndex <= 0)
                    
                    Spacer()
                    
                    Text(currentMonthName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                    .disabled(currentMonthIndex >= monthsWithData.count - 1)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var shareInputSection: some View {
        VStack(spacing: 12) {
            // Only show setup section if no data is available
            if cloudKitManager.sharedSchedules.isEmpty && cloudKitManager.sharedMonthlyNotes.isEmpty && !cloudKitManager.isLoading {
                HStack {
                    Text("📤 Setup Required")
                        .font(.headline)
                    Spacer()
                    Button("Add Share") {
                        showingShareInput = true
                    }
                    .foregroundColor(.blue)
                }
                
                Text("Connect to Provider Schedule Calendar")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var monthlyScheduleSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if cloudKitManager.sharedSchedules.isEmpty && cloudKitManager.sharedMonthlyNotes.isEmpty {
                Text("No schedule data available")
                    .foregroundColor(.gray)
                    .italic()
            } else if !monthsWithData.isEmpty && currentMonthIndex < monthsWithData.count {
                // Show only the currently selected month
                let currentMonth = monthsWithData[currentMonthIndex]
                monthSection(for: currentMonth)
            } else {
                Text("No data for selected month")
                    .foregroundColor(.gray)
                    .italic()
            }
        }
    }
    
    private func monthSection(for month: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month header removed - now shown in navigation header
            
            // Monthly notes for this month (if any)
            let monthlyNotes = getMonthlyNotesFor(month: month)
            if !monthlyNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly Notes")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ForEach(monthlyNotes) { note in
                        MonthlyNoteRowView(note: note)
                    }
                }
            }
            
            // Schedule entries for this month
            let schedules = getSchedulesFor(month: month)
            if !schedules.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule Entries")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ForEach(schedules) { schedule in
                        ScheduleRowView(schedule: schedule)
                    }
                }
            }
            
            // Show message if month has no data
            if monthlyNotes.isEmpty && schedules.isEmpty {
                Text("No data for this month")
                    .foregroundColor(.gray)
                    .italic()
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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
            errorMessage = "Invalid share URL format. Please check the URL and try again."
            showingErrorAlert = true
            return
        }
        
        debugLog("🔗 SV DEBUG: Attempting to accept share from URL: \(url.absoluteString)")
        
        cloudKitManager.acceptShareFromURL(url) { success, error in
            DispatchQueue.main.async {
                if success {
                    debugLog("✅ SV DEBUG: Share accepted successfully!")
                    showingShareInput = false
                    shareURL = ""
                    cloudKitManager.checkForSharedData()
                } else {
                    debugLog("❌ SV DEBUG: Share acceptance failed")
                    if let error = error {
                        debugLog("❌ SV DEBUG: Error details: \(error.localizedDescription)")
                        if let ckError = error as? CKError {
                            debugLog("❌ SV DEBUG: CloudKit Error Code: \(ckError.code.rawValue)")
                        }
                    }
                    
                    errorMessage = """
                    Failed to accept share.
                    
                    Error: \(error?.localizedDescription ?? "Unknown error")
                    
                    Please check:
                    • You're signed into iCloud
                    • The share URL is valid
                    • You have internet connection
                    """
                    showingErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - Print Functions
    private func printCalendar() {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        
        printInfo.outputType = .general
        printInfo.jobName = "Provider Schedule - 12 Months"
        printInfo.orientation = .portrait
        
        printController.printInfo = printInfo
        printController.showsNumberOfCopies = true
        
        // Create printable content using HTML
        let htmlContent = generateFullYearHTML()
        let formatter = UIMarkupTextPrintFormatter(markupText: htmlContent)
        formatter.perPageContentInsets = UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30)
        
        printController.printFormatter = formatter
        
        // Present print dialog
        printController.present(animated: true) { (controller, completed, error) in
            if let error = error {
                debugLog("Print error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - HTML Generation (Same as PSC)
    private func generateFullYearHTML() -> String {
        var fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: Arial, sans-serif; margin: 0; padding: 0; }
                .page { page-break-after: always; padding: 20px; height: 100vh; box-sizing: border-box; }
                .page:last-child { page-break-after: avoid; }
                .header { text-align: center; margin-bottom: 15px; }
                .title { font-size: 24px; font-weight: bold; margin-bottom: 8px; }
                .month-title { font-size: 18px; font-weight: bold; margin-bottom: 15px; }
                .notes { margin-bottom: 15px; padding: 8px; background-color: #f0f0f0; font-size: 12px; }
                .calendar { width: 100%; border-collapse: collapse; margin-bottom: 15px; }
                .calendar th, .calendar td { border: 1.5px solid #000; padding: 4px; vertical-align: top; }
                .calendar th { background-color: #e0e0e0; text-align: center; height: 25px; font-size: 12px; font-weight: bold; }
                .calendar td { height: 80px; width: 14.28%; }
                .day-number { font-weight: bold; font-size: 12px; margin-bottom: 3px; }
                .schedule-line { font-size: 9px; margin: 1px 0; line-height: 1.2; }
                @page { margin: 0.5in; }
            </style>
        </head>
        <body>
        """
        
        // Generate each month as a separate page
        for month in monthsToShow {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMMM yyyy"
            
            let monthlyNotes = getMonthlyNotes(for: month)
            let dailySchedules = getDailySchedules(for: month)
            
            fullHTML += """
            <div class="page">
                <div class="header">
                    <div class="title">PROVIDER SCHEDULE</div>
                    <div class="month-title">\(monthFormatter.string(from: month))</div>
                </div>
            """
            
            // Add monthly notes if they exist
            if !monthlyNotes.isEmpty {
                fullHTML += "<div class=\"notes\"><strong>Notes:</strong><br>"
                for note in monthlyNotes {
                    if !note.isEmpty {
                        fullHTML += "• \(note)<br>"
                    }
                }
                fullHTML += "</div>"
            }
            
            // Add calendar table
            fullHTML += "<table class=\"calendar\">"
            
            // Days of week header
            fullHTML += "<tr>"
            for day in Calendar.current.shortWeekdaySymbols {
                fullHTML += "<th>\(day)</th>"
            }
            fullHTML += "</tr>"
            
            // Get properly aligned calendar grid
            let calendarDays = getCalendarDaysWithAlignment(for: month)
            let weeks = calendarDays.chunked(into: 7)
            
            for week in weeks {
                fullHTML += "<tr>"
                for date in week {
                    if Calendar.current.isDate(date, equalTo: month, toGranularity: .month) {
                        let dayNumber = Calendar.current.component(.day, from: date)
                        let schedule = dailySchedules[date] ?? ["", "", "", ""]
                        
                        fullHTML += "<td>"
                        fullHTML += "<div class=\"day-number\">\(dayNumber)</div>"
                        fullHTML += "<div class=\"schedule-line\"><strong>OS:</strong> \(schedule[0])</div>"
                        fullHTML += "<div class=\"schedule-line\"><strong>CL:</strong> \(schedule[1])</div>"
                        fullHTML += "<div class=\"schedule-line\"><strong>OFF:</strong> \(schedule[2])</div>"
                        fullHTML += "<div class=\"schedule-line\"><strong>CALL:</strong> \(schedule[3])</div>"
                        fullHTML += "</td>"
                    } else {
                        fullHTML += "<td></td>"
                    }
                }
                fullHTML += "</tr>"
            }
            
            fullHTML += "</table></div>"
        }
        
        fullHTML += "</body></html>"
        return fullHTML
    }
    
    private var monthsToShow: [Date] {
        var months: [Date] = []
        
        for i in 0..<12 {
            if let month = Calendar.current.date(byAdding: .month, value: i, to: Date()) {
                months.append(month)
            }
        }
        
        return months
    }
    
    private var monthsWithData: [Date] {
        let calendar = Calendar.current
        var monthsSet: Set<Date> = []
        
        // Add months that have schedule data
        for schedule in cloudKitManager.sharedSchedules {
            if let date = schedule.date {
                let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
                monthsSet.insert(monthStart)
            }
        }
        
        // Add months that have monthly notes
        for note in cloudKitManager.sharedMonthlyNotes {
            var components = DateComponents()
            components.year = note.year
            components.month = note.month
            components.day = 1
            if let monthStart = calendar.date(from: components) {
                monthsSet.insert(monthStart)
            }
        }
        
        // Sort months chronologically
        return Array(monthsSet).sorted()
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    private var currentMonthName: String {
        guard !monthsWithData.isEmpty, currentMonthIndex < monthsWithData.count else {
            return "No Data"
        }
        return monthFormatter.string(from: monthsWithData[currentMonthIndex])
    }
    
    private func previousMonth() {
        if currentMonthIndex > 0 {
            currentMonthIndex -= 1
            scrollToCurrentMonth()
        }
    }
    
    private func nextMonth() {
        if currentMonthIndex < monthsWithData.count - 1 {
            currentMonthIndex += 1
            scrollToCurrentMonth()
        }
    }
    
    private func scrollToCurrentMonth() {
        // Since we're now showing only one month at a time, 
        // this function ensures the UI updates when month changes
        // The month change is handled by the currentMonthIndex state change
    }
    
    private func initializeCurrentMonth() {
        guard !monthsWithData.isEmpty else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Try to find current month in the data
        if let currentMonthIndex = monthsWithData.firstIndex(where: { month in
            calendar.isDate(month, equalTo: now, toGranularity: .month)
        }) {
            self.currentMonthIndex = currentMonthIndex
        } else {
            // If current month not found, default to the most recent month
            self.currentMonthIndex = monthsWithData.count - 1
        }
    }
    
    private func getMonthlyNotesFor(month: Date) -> [SharedMonthlyNotesRecord] {
        let calendar = Calendar.current
        let monthNumber = calendar.component(.month, from: month)
        let yearNumber = calendar.component(.year, from: month)
        
        return cloudKitManager.sharedMonthlyNotes.filter { note in
            note.month == monthNumber && note.year == yearNumber
        }
    }
    
    private func getSchedulesFor(month: Date) -> [SharedScheduleRecord] {
        let calendar = Calendar.current
        
        return cloudKitManager.sharedSchedules.filter { schedule in
            guard let scheduleDate = schedule.date else { return false }
            return calendar.isDate(scheduleDate, equalTo: month, toGranularity: .month)
        }.sorted { schedule1, schedule2 in
            guard let date1 = schedule1.date, let date2 = schedule2.date else { return false }
            return date1 < date2
        }
    }
    
    private func getCalendarDaysWithAlignment(for month: Date) -> [Date] {
        let calendar = Calendar.current
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
    
    private func getMonthlyNotes(for month: Date) -> [String] {
        let calendar = Calendar.current
        let monthNumber = calendar.component(.month, from: month)
        let yearNumber = calendar.component(.year, from: month)
        
        guard let monthlyNote = cloudKitManager.sharedMonthlyNotes.first(where: { note in
            note.month == monthNumber && note.year == yearNumber
        }) else {
            return []
        }
        
        var notes: [String] = []
        if let line1 = monthlyNote.line1, !line1.isEmpty { notes.append(line1) }
        if let line2 = monthlyNote.line2, !line2.isEmpty { notes.append(line2) }
        if let line3 = monthlyNote.line3, !line3.isEmpty { notes.append(line3) }
        
        return notes
    }
    
    private func getDailySchedules(for month: Date) -> [Date: [String]] {
        let calendar = Calendar.current
        var schedules: [Date: [String]] = [:]
        
        let monthStart = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let monthEnd = calendar.dateInterval(of: .month, for: month)?.end ?? month
        
        for schedule in cloudKitManager.sharedSchedules {
            guard let date = schedule.date,
                  date >= monthStart && date < monthEnd else { continue }
            
            let dayStart = calendar.startOfDay(for: date)
            schedules[dayStart] = [
                schedule.line1 ?? "",
                schedule.line2 ?? "",
                schedule.line3 ?? "",
                schedule.line4 ?? ""
            ]
        }
        
        return schedules
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
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
                    Text("OS: \(line1)")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                if let line2 = schedule.line2, !line2.isEmpty {
                    Text("CL: \(line2)")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                if let line3 = schedule.line3, !line3.isEmpty {
                    Text("OFF: \(line3)")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                if let line4 = schedule.line4, !line4.isEmpty {
                    Text("CALL: \(line4)")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
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
                    Text("OS: \(line1)")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                if let line2 = note.line2, !line2.isEmpty {
                    Text("CL: \(line2)")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                if let line3 = note.line3, !line3.isEmpty {
                    Text("OFF: \(line3)")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
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


#Preview {
    ContentView()
        .environmentObject(CloudKitManager.shared)
}
