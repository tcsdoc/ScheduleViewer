import SwiftUI
import CloudKit
import UIKit
import PDFKit

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
            
            // Connection status row - centered
            HStack {
                Spacer()
                
                if cloudKitManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                    }
                    .foregroundColor(.blue)
                } else if !cloudKitManager.cloudKitAvailable {
                    Text("⚠️ Connection Issue")
                        .foregroundColor(.red)
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
    
    // MARK: - Print Functions (PDFKit Native - Same as PSC)
    private func printCalendar() {
        // Generate PDF data using our breakthrough PDFKit solution
        guard let pdfData = generateCalendarPDF() else {
            debugLog("Failed to generate PDF")
            return
        }
        
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        
        printInfo.outputType = .general
        printInfo.jobName = "Provider Schedule Calendar"
        printInfo.orientation = .portrait
        
        printController.printInfo = printInfo
        printController.showsNumberOfCopies = true
        
        // Use PDF data directly (no CSS nightmares!)
        printController.printingItem = pdfData
        
        // Present print dialog
        printController.present(animated: true) { (controller, completed, error) in
            if let error = error {
                debugLog("Print error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - PDF Generation (PDFKit Native - Breakthrough Solution!)
    private func generateCalendarPDF() -> Data? {
        // Standard US Letter size: 612 x 792 points
        let pageSize = CGSize(width: 612, height: 792)
        let pageMargin: CGFloat = 36 // 0.5 inch margins
        let contentRect = CGRect(
            x: pageMargin,
            y: pageMargin,
            width: pageSize.width - (pageMargin * 2),
            height: pageSize.height - (pageMargin * 2)
        )
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: pageSize), nil)
        
        for month in monthsToShow {
            UIGraphicsBeginPDFPage()
            
            let context = UIGraphicsGetCurrentContext()!
            
            // Draw month for this page
            drawCalendarMonth(month: month, in: contentRect, context: context)
        }
        
        UIGraphicsEndPDFContext()
        return pdfData as Data
    }
    
    private func drawCalendarMonth(month: Date, in rect: CGRect, context: CGContext) {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthTitle = monthFormatter.string(from: month)
        
        var currentY = rect.minY
        
        // Draw month title (compact font to save space)
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let titleSize = monthTitle.size(withAttributes: [.font: titleFont])
        let titleRect = CGRect(
            x: rect.midX - titleSize.width / 2,
            y: currentY,
            width: titleSize.width,
            height: titleSize.height
        )
        monthTitle.draw(in: titleRect, withAttributes: [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ])
        currentY += titleSize.height + 10
        
        // Draw monthly notes if they exist (using SV's data structure)
        let monthlyNotes = getSVMonthlyNotes(for: month)
        if !monthlyNotes.isEmpty {
            let notesFont = UIFont.systemFont(ofSize: 11)
            var notesText = "Notes: "
            notesText += monthlyNotes.joined(separator: " | ")
            
            let notesSize = notesText.size(withAttributes: [.font: notesFont])
            let notesRect = CGRect(x: rect.minX, y: currentY, width: rect.width, height: notesSize.height)
            
            // Draw compact background
            context.setFillColor(UIColor.lightGray.cgColor)
            context.fill(notesRect.insetBy(dx: -3, dy: -2))
            
            // Draw text
            notesText.draw(in: notesRect, withAttributes: [
                .font: notesFont,
                .foregroundColor: UIColor.black
            ])
            currentY += notesSize.height + 5
        }
        
        // Calculate calendar grid dimensions (no gap between notes and calendar)
        let availableHeight = rect.maxY - currentY - 5
        let cellWidth = rect.width / 7
        let headerHeight: CGFloat = 30
        let calendarHeight = availableHeight - headerHeight
        
        // Determine how many weeks this month needs (dynamic sizing!)
        let weeks = getWeeksForMonth(month)
        let cellHeight = calendarHeight / CGFloat(weeks)
        
        // Draw calendar grid
        drawCalendarGrid(
            month: month,
            startY: currentY,
            rect: rect,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            headerHeight: headerHeight,
            context: context
        )
    }
    
    // MARK: - PDFKit Helper Functions (Adapted from PSC)
    private func getWeeksForMonth(_ month: Date) -> Int {
        // Use the exact same logic as our calendar generation
        let calendarDays = getCalendarDaysWithAlignment(for: month)
        let weeks = calendarDays.chunked(into: 7)
        
        // Count only weeks that contain days from the target month
        var weeksWithContent = 0
        for week in weeks {
            let hasMonthContent = week.contains { date in
                Calendar.current.isDate(date, equalTo: month, toGranularity: .month)
            }
            if hasMonthContent {
                weeksWithContent += 1
            }
        }
        
        return weeksWithContent
    }
    
    private func drawCalendarGrid(month: Date, startY: CGFloat, rect: CGRect, cellWidth: CGFloat, cellHeight: CGFloat, headerHeight: CGFloat, context: CGContext) {
        var currentY = startY
        
        // Draw weekday headers
        let headerFont = UIFont.boldSystemFont(ofSize: 12)
        let weekdays = Calendar.current.shortWeekdaySymbols
        
        for (index, weekday) in weekdays.enumerated() {
            let headerRect = CGRect(
                x: rect.minX + CGFloat(index) * cellWidth,
                y: currentY,
                width: cellWidth,
                height: headerHeight
            )
            
            // Draw header background
            context.setFillColor(UIColor.lightGray.cgColor)
            context.fill(headerRect)
            
            // Draw header border
            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(1.0)
            context.stroke(headerRect)
            
            // Draw header text
            let textSize = weekday.size(withAttributes: [.font: headerFont])
            let textRect = CGRect(
                x: headerRect.midX - textSize.width / 2,
                y: headerRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            weekday.draw(in: textRect, withAttributes: [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ])
        }
        currentY += headerHeight
        
        // Draw calendar days (only the weeks we actually need)
        let calendarDays = getCalendarDaysWithAlignment(for: month)
        let allWeeks = calendarDays.chunked(into: 7)
        
        // Only draw weeks that contain days from this month
        let weeksToShow = allWeeks.filter { week in
            week.contains { date in
                Calendar.current.isDate(date, equalTo: month, toGranularity: .month)
            }
        }
        
        for week in weeksToShow {
            for (dayIndex, date) in week.enumerated() {
                let cellRect = CGRect(
                    x: rect.minX + CGFloat(dayIndex) * cellWidth,
                    y: currentY,
                    width: cellWidth,
                    height: cellHeight
                )
                
                // Draw cell border
                context.setStrokeColor(UIColor.black.cgColor)
                context.setLineWidth(1.0)
                context.stroke(cellRect)
                
                // Only draw content for days in the current month
                if Calendar.current.isDate(date, equalTo: month, toGranularity: .month) {
                    drawDayCell(date: date, in: cellRect, context: context, month: month)
                }
            }
            currentY += cellHeight
        }
    }
    
    private func drawDayCell(date: Date, in rect: CGRect, context: CGContext, month: Date) {
        let dayNumber = Calendar.current.component(.day, from: date)
        let schedule = getSVDailySchedule(for: date)
        
        let padding: CGFloat = 2
        let contentRect = rect.insetBy(dx: padding, dy: padding)
        var textY = contentRect.minY
        
        // Draw day number
        let dayFont = UIFont.boldSystemFont(ofSize: 10)
        let dayText = "\(dayNumber)"
        
        dayText.draw(at: CGPoint(x: contentRect.minX, y: textY), withAttributes: [
            .font: dayFont,
            .foregroundColor: UIColor.black
        ])
        textY += dayFont.lineHeight + 1
        
        // Draw schedule data - label on one line, value on next line (monochrome)
        let scheduleFont = UIFont.systemFont(ofSize: 7)
        let maxWidth = contentRect.width
        
        // OS field
        drawLabelAndValue("OS", value: schedule[0], 
                         startY: &textY, at: contentRect.minX, 
                         maxWidth: maxWidth, font: scheduleFont, color: UIColor.black)
        
        // CL field
        drawLabelAndValue("CL", value: schedule[1], 
                         startY: &textY, at: contentRect.minX, 
                         maxWidth: maxWidth, font: scheduleFont, color: UIColor.black)
        
        // OFF field
        drawLabelAndValue("OFF", value: schedule[2], 
                         startY: &textY, at: contentRect.minX, 
                         maxWidth: maxWidth, font: scheduleFont, color: UIColor.black)
        
        // CALL field
        drawLabelAndValue("CALL", value: schedule[3], 
                         startY: &textY, at: contentRect.minX, 
                         maxWidth: maxWidth, font: scheduleFont, color: UIColor.black)
    }
    
    private func drawLabelAndValue(_ label: String, value: String?, startY: inout CGFloat, at x: CGFloat, maxWidth: CGFloat, font: UIFont, color: UIColor) {
        let lineHeight: CGFloat = 8
        
        // Draw label on first line
        label.draw(at: CGPoint(x: x, y: startY), withAttributes: [
            .font: font,
            .foregroundColor: color
        ])
        startY += lineHeight
        
        // Draw value on second line (if it exists)
        if let value = value, !value.isEmpty {
            let maxChars = Int(maxWidth / 4) // Rough estimate: 4 points per character
            let displayValue = value.count > maxChars ? String(value.prefix(maxChars - 1)) + "…" : value
            
            displayValue.draw(at: CGPoint(x: x, y: startY), withAttributes: [
                .font: font,
                .foregroundColor: color
            ])
        }
        startY += lineHeight
    }
    
    // MARK: - SV Data Access Helper Functions
    private func getSVMonthlyNotes(for month: Date) -> [String] {
        // Convert SV's SharedMonthlyNotesRecord to array format
        let calendar = Calendar.current
        let monthlyNotesForMonth = cloudKitManager.sharedMonthlyNotes.filter { note in
            guard let noteDate = calendar.date(from: DateComponents(year: note.year, month: note.month)) else { return false }
            return calendar.isDate(noteDate, equalTo: month, toGranularity: .month)
        }
        
        var notes: [String] = []
        for note in monthlyNotesForMonth {
            if let line1 = note.line1, !line1.isEmpty {
                notes.append(line1)
            }
            if let line2 = note.line2, !line2.isEmpty {
                notes.append(line2)
            }
        }
        return notes
    }
    
    private func getSVDailySchedule(for date: Date) -> [String] {
        // Convert SV's SharedScheduleRecord to array format [OS, CL, OFF, CALL]
        let calendar = Calendar.current
        let scheduleForDate = cloudKitManager.sharedSchedules.first { schedule in
            guard let scheduleDate = schedule.date else { return false }
            return calendar.isDate(scheduleDate, inSameDayAs: date)
        }
        
        return [
            scheduleForDate?.line1 ?? "",
            scheduleForDate?.line2 ?? "",
            scheduleForDate?.line3 ?? "",
            scheduleForDate?.line4 ?? ""
        ]
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
        let now = Date()
        let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        var monthsSet: Set<Date> = []
        
        // Add months that have schedule data (current month and future only)
        for schedule in cloudKitManager.sharedSchedules {
            if let date = schedule.date {
                let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
                if monthStart >= currentMonthStart {
                    monthsSet.insert(monthStart)
                }
            }
        }
        
        // Add months that have monthly notes (current month and future only)
        for note in cloudKitManager.sharedMonthlyNotes {
            var components = DateComponents()
            components.year = note.year
            components.month = note.month
            components.day = 1
            if let monthStart = calendar.date(from: components) {
                if monthStart >= currentMonthStart {
                    monthsSet.insert(monthStart)
                }
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
