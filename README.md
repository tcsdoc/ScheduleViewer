# ScheduleViewer

**A read-only iOS app for healthcare providers to view their work schedules across multiple clinic locations.**

## What This App Does

ScheduleViewer displays **provider work schedules** for a multi-location medical clinic. Providers use this app to see which clinic location they're assigned to work on any given day.

### ⚠️ IMPORTANT - What This App Is NOT:
- **NOT** an appointment viewer
- **NOT** a patient schedule viewer  
- **NOT** related to patient data in any way
- **NO** patient information is displayed or accessed

## Purpose

Healthcare providers at Gulf Coast Children's Clinic work rotating schedules across two locations. This app allows them to quickly check:
- Which location they're assigned to on any day
- Which colleagues are working at each location
- Who is off duty
- Who is on-call

## Clinic Locations

The app tracks provider assignments for two clinic locations:

- **OS** = **Ocean Springs** clinic location
- **CL** = **Cedar Lake** clinic location
- **OFF** = Provider is off duty
- **CALL** = Provider is on-call

### Code Implementation Note:
In the codebase, these appear as:
- `line1` / `CD_line1` → OS (Ocean Springs)
- `line2` / `CD_line2` → CL (Cedar Lake)
- `line3` / `CD_line3` → OFF (Off duty)
- `line4` / `CD_line4` → CALL (On-call)

## Key Features

- **Calendar View**: Month-by-month display of provider schedules
- **Location Display**: Shows which providers are assigned to OS, CL, or are OFF/CALL each day
- **Monthly Notes**: Clinic-wide notes for each month (holidays, special schedules, etc.)
- **Read-Only Access**: View-only - no editing capabilities
- **Print Functionality**: Print monthly calendars using native PDFKit
- **CloudKit Integration**: Syncs with Provider Schedule Calendar (PSC) app
- **Multi-Device**: Works on iPhone and iPad
- **Offline Viewing**: Cached data available when offline

## Architecture

### Companion App Relationship

**ScheduleViewer** is the read-only viewer companion to **Provider Schedule Calendar (PSC)**:
- **PSC**: Admin app - creates and manages provider schedules (write access)
- **ScheduleViewer**: Provider app - views provider schedules (read-only access)

Both apps use the same CloudKit container: `iCloud.com.gulfcoast.ProviderCalendar`

### CloudKit Sharing Model

- **Database**: Shared CloudKit Database (receives shared zones from PSC)
- **Zone**: `ProviderScheduleZone` (custom zone shared by PSC)
- **Share Type**: Zone-level sharing with `.readOnly` public permission
- **Container**: `iCloud.com.gulfcoast.ProviderCalendar`

### Data Models

#### SharedScheduleRecord
Represents one day's provider assignments:
```swift
struct SharedScheduleRecord {
    let id: String              // Unique record identifier
    let date: Date?             // Date for this schedule
    let line1: String?          // OS (Ocean Springs) - provider name
    let line2: String?          // CL (Cedar Lake) - provider name
    let line3: String?          // OFF - provider name(s)
    let line4: String?          // CALL - provider name
    let zoneID: CKRecordZone.ID // Source zone
}
```

#### SharedMonthlyNotesRecord
Represents monthly clinic-wide notes:
```swift
struct SharedMonthlyNotesRecord {
    let id: String              // Unique record identifier
    let month: Int              // Month (1-12)
    let year: Int               // Year
    let line1: String?          // Note line 1
    let line2: String?          // Note line 2
    let line3: String?          // Note line 3
    let zoneID: CKRecordZone.ID // Source zone
}
```

### CloudKit Record Types

**CD_DailySchedule**: Daily provider location assignments
- `CD_date`: Date
- `CD_id`: Record identifier
- `CD_line1`: Ocean Springs assignment
- `CD_line2`: Cedar Lake assignment
- `CD_line3`: Off duty providers
- `CD_line4`: On-call provider

**CD_MonthlyNotes**: Monthly clinic notes
- `CD_month`: Integer (1-12)
- `CD_year`: Integer
- `CD_id`: Record identifier  
- `CD_line1`: Note text line 1
- `CD_line2`: Note text line 2
- `CD_line3`: Note text line 3

## Technical Implementation

### Key Components

**ScheduleViewerApp.swift**
- App entry point
- URL handling for CloudKit share acceptance
- Manages CloudKitManager lifecycle

**CloudKitManager.swift** (@MainActor class)
- CloudKit operations and sharing
- Zone discovery and management
- Data fetching with pagination
- Share acceptance flow
- UserDefaults persistence of accepted zones

**ContentView.swift**
- Main SwiftUI interface
- Month navigation
- Schedule display
- PDFKit-based print functionality

### CloudKit Operations Flow

1. **App Launch**:
   - Check CloudKit availability
   - Load previously accepted zones from UserDefaults
   - Discover shared zones via `sharedDatabase.allRecordZones()`
   - Fetch schedule data from accepted zones

2. **Share Acceptance**:
   - User pastes CloudKit share URL
   - `CKFetchShareMetadataOperation` fetches share metadata
   - `CKAcceptSharesOperation` accepts the share
   - Zone ID saved to UserDefaults for persistence
   - Data fetched from newly accepted zone

3. **Data Fetching**:
   - Query each accepted zone separately
   - Use cursor-based pagination for large datasets
   - Remove duplicates by date (keep most complete record)
   - Update `@Published` properties to refresh UI

### Print Functionality (v4.0 Breakthrough)

Uses **native PDFKit** (not CSS/HTML) for reliable calendar printing:

```swift
generateCalendarPDF() -> Data?
- Creates PDF context (US Letter: 612x792 points)
- Iterates through months with data
- Draws calendar grid with provider assignments
- Dynamic week sizing (only weeks needed)
- Monochrome output for printing
```

**Print Layout**:
- Page margins: 0.5 inch (36 points)
- Month title: 16pt bold
- Monthly notes: Compact single-line format
- Calendar grid: Dynamic height based on weeks needed
- Day cells: Provider names for OS/CL/OFF/CALL

## User Interface

### Header Section
- App name and version
- Connection status indicator
- Print button
- Month navigation (previous/next)

### Main Content
- Monthly schedule display (one month at a time)
- Monthly notes section (if present)
- Daily schedule entries with location assignments
- Pull-to-refresh support

### Share Input
- Setup prompt when no data available
- Share URL input sheet
- Error handling with user-friendly messages

## Setup and Usage

### Initial Setup (One-Time)

1. Install ScheduleViewer on iOS device
2. Launch app - see "Setup Required" prompt
3. Tap "Add Share" button
4. PSC admin creates share and emails link
5. Paste share URL into ScheduleViewer
6. App accepts share and loads schedule data

### Daily Usage

1. Open app - automatically loads latest schedule
2. Navigate months using arrows
3. View provider assignments:
   - **Date**: The calendar date
   - **OS**: Provider(s) working at Ocean Springs
   - **CL**: Provider(s) working at Cedar Lake
   - **OFF**: Provider(s) off duty
   - **CALL**: Provider on-call
4. Print calendar if needed

## Requirements

- iOS 15.0 or later
- iPhone or iPad
- iCloud account (must be invited to share by PSC admin)
- Internet connection for initial sync (cached for offline viewing)

## Privacy and Security

- **Read-Only**: No modification capabilities
- **No Patient Data**: App does not access or display any patient information
- **CloudKit Sharing**: Secure zone-level sharing via Apple's CloudKit
- **No Data Collection**: App does not collect or transmit user data
- **iCloud Security**: Leverages Apple's iCloud security infrastructure

## Version History

- **v4.0.3** (Current): Fixed app opening to current month, removed past month display
- **v4.0**: PDFKit native printing breakthrough, improved reliability
- **v3.7.5**: Previous version with CSS-based printing
- **Earlier**: Initial releases

## Development Notes

### Testing Considerations

- Test with multiple accepted shares
- Verify offline viewing of cached data
- Test share acceptance flow
- Validate print output for various month lengths (4-6 weeks)
- Test on multiple device sizes (iPhone SE through iPad Pro)

### Known Technical Details

- Share acceptance persists to UserDefaults as `acceptedSharedZones`
- Duplicate records handled client-side (keeps most complete by date)
- Both shared database AND private database queried (for own zones)
- Zone discovery fetches ALL shared zones (no filtering by name)

### Build Configuration

- **Container**: `iCloud.com.gulfcoast.ProviderCalendar`
- **Entitlements**: 
  - CloudKit
  - CloudKit sharing
  - Background modes (remote notifications)
  - `com.apple.developer.cloudkit-share-handling` (required for share acceptance)
- **Environment**: Production

## Support

This app is proprietary software developed for Gulf Coast Children's Clinic provider scheduling.

For technical support, contact the clinic administrator who manages Provider Schedule Calendar.

## License

Proprietary - Gulf Coast Children's Clinic
