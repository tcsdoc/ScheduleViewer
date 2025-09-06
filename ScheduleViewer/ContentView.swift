import SwiftUI
import CloudKit

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
                VStack(spacing: 2) {
                    Text("✅ \(cloudKitManager.sharedSchedules.count) schedules")
                        .foregroundColor(.green)
                    Text("✅ \(cloudKitManager.sharedMonthlyNotes.count) monthly notes")
                        .foregroundColor(.green)
                }
                .font(.caption)
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

#Preview {
    ContentView()
        .environmentObject(CloudKitManager.shared)
}
