# App Store Connect Metadata for ScheduleViewer

## App Information

### Basic Details
- **App Name**: ScheduleViewer - Provider Work Schedule
- **Bundle ID**: com.gulfcoast.ScheduleViewer
- **SKU**: scheduleviewer-ios-gulfcoast
- **Primary Language**: English (US)
- **Category**: Medical
- **Subcategory**: Healthcare & Fitness

### Age Rating
- **Age Rating**: 4+
- **Content Descriptors**: None
- **Interactive Elements**: None

## App Description

### App Store Description
```
ScheduleViewer - Multi-Location Provider Schedule Viewer

Know your work schedule at a glance. ScheduleViewer shows healthcare providers their work assignments across multiple clinic locations in an easy-to-read calendar format.

WHAT IT DOES:
• View which clinic location you're working at each day
• See colleague coverage at both clinic locations
• Check who is on-call or off duty
• View monthly clinic notes and announcements
• Print monthly schedules

PERFECT FOR:
• Healthcare providers with rotating schedules
• Multi-location medical clinics
• Providers who work variable days/locations
• Clinic staff needing coverage visibility

KEY FEATURES:
• Calendar view of provider location assignments
• Two-location tracking (Ocean Springs & Cedar Lake clinics)
• Monthly clinic notes display
• Native PDF printing
• Works on iPhone and iPad
• Offline viewing of cached schedules
• Secure CloudKit sync with admin app

IMPORTANT - THIS APP IS NOT:
• NOT an appointment viewer
• NOT a patient schedule app
• Contains NO patient information

DESIGNED FOR GULF COAST CHILDREN'S CLINIC:
This app is specifically designed for providers at Gulf Coast Children's Clinic who work rotating schedules between the Ocean Springs and Cedar Lake locations.

SECURITY:
• Read-only access (view schedules only)
• No patient data access
• Secure CloudKit sharing
• No personal data collection

SETUP:
Requires one-time setup with share link from clinic administrator who uses Provider Schedule Calendar (admin app).

Download ScheduleViewer and always know where you're working!
```

### What's New in This Version
```
Version 4.0.2 - Bug Fix

FIXED:
• App now opens to current month instead of old months
• Past months are automatically hidden - only current and future months displayed
• Providers no longer need to scroll to find current assignments

This update addresses the most requested improvement from providers - immediate access to current schedules without scrolling through past months.
```

## Keywords
```
provider schedule,work schedule,clinic schedule,medical staff,healthcare provider,location schedule,multi-location,rotating schedule,provider calendar,clinic locations,work assignments,on-call schedule,read-only viewer,ocean springs,cedar lake
```

## Screenshots

### iPhone Screenshots Required
1. **6.7" iPhone (iPhone 14 Pro Max, iPhone 15 Pro Max)**
   - Monthly calendar view showing provider location assignments
   - Month navigation interface
   - Setup screen with share URL input

2. **5.5" iPhone (iPhone 8 Plus)**
   - Monthly calendar view showing provider location assignments
   - Monthly notes display
   - Connection status indicators

### iPad Screenshots Required
1. **12.9" iPad Pro**
   - Full monthly calendar view with provider assignments
   - Monthly notes section
   - Print preview

2. **11" iPad Pro**
   - Monthly calendar view with larger display
   - Navigation and status indicators
   - Share acceptance interface

## App Review Information

### Contact Information
- **First Name**: [Admin First Name]
- **Last Name**: [Admin Last Name]
- **Phone Number**: [Clinic Phone Number]
- **Email**: [Admin Email Address]

### Demo Account
**Note**: This app requires a CloudKit share invitation from the Provider Schedule Calendar admin app. For App Review testing:

- **Test Account Setup**: App Review will need a pre-configured share link
- **Demo Share URL**: [Provide test share URL during submission]
- **Additional Notes**: 
  - App displays provider work schedules, NOT patient appointments
  - No patient data is accessed or displayed
  - Requires CloudKit share acceptance (one-time setup)
  - Demo data shows sample provider names at clinic locations

### Notes for Review
```
ScheduleViewer - Provider Work Schedule Viewer

IMPORTANT FOR APP REVIEW:
This app displays PROVIDER WORK SCHEDULES (which staff members work at which clinic locations), NOT patient appointments. There is NO patient data of any kind.

WHAT THE APP SHOWS:
• Provider names assigned to clinic locations (Ocean Springs, Cedar Lake)
• Which providers are off duty
• Which provider is on-call
• Monthly clinic notes (holidays, schedule changes, etc.)

FIELD EXPLANATIONS IN APP:
• OS = Ocean Springs (clinic location in Ocean Springs, MS)
• CL = Cedar Lake (clinic location in Cedar Lake area)
• OFF = Providers who are off duty
• CALL = Provider who is on-call

APP ARCHITECTURE:
• Companion to "Provider Schedule Calendar" (admin app that creates schedules)
• Read-only viewer (no editing capabilities)
• Uses CloudKit zone sharing for data access
• Requires one-time share acceptance from admin

TESTING INSTRUCTIONS:
1. Launch app on iPhone or iPad
2. App will prompt for CloudKit share URL (one-time setup)
3. [Provide test share URL during submission]
4. Paste share URL and tap "Accept Share"
5. App loads and displays provider work schedules
6. Navigate between months using arrow buttons
7. Test print functionality with Print button
8. Pull down to refresh data

NO PATIENT DATA:
• App does NOT access patient information
• App does NOT show appointments
• App does NOT display PHI (Protected Health Information)
• Simply shows which providers work at which clinic locations on which days

The app is designed for healthcare providers to check their work location assignments and see colleague coverage at a multi-location clinic.
```

## Pricing and Availability

### Pricing
- **Price**: Free
- **In-App Purchases**: None
- **Subscription**: None

### Availability
- **Countries**: United States
- **Languages**: English
- **Devices**: iPhone, iPad

## App Store Optimization

### App Store Title
```
ScheduleViewer - Clinic Work Schedule
```

### Subtitle
```
Provider location schedule viewer
```

### Promotional Text
```
View your work schedule and clinic location assignments in an easy-to-use calendar format. Perfect for providers with rotating multi-location schedules.
```

## Legal Information

### Privacy Policy URL
```
https://www.gulfcoastchildrensclinic.com/scheduleviewer-privacy
```

### Privacy Policy Summary
- **Data Collection**: None
- **Data Sharing**: None
- **Patient Data Access**: None (app does not access patient information)
- **CloudKit Usage**: Read-only access to provider work schedules
- **Analytics**: None
- **Third-Party SDKs**: None

### License Agreement
```
Standard Apple License Agreement
```

### Export Compliance
- **Uses Encryption**: No
- **Export Compliance Documentation**: Not required

## App Store Connect Settings

### App Information
- **Content Rights**: You own or have licensed all rights to your app
- **Advertising Identifier (IDFA)**: No
- **App Uses Non-Exempt Encryption**: No
- **Third-Party Content**: No

### App Review
- **Auto-Release**: Yes
- **Release Type**: Manual

### Version Release
- **Phased Release**: No
- **Automatic Release**: Yes

## Build Information

### Build Details
- **Version**: 4.0.2
- **Build**: 4
- **Minimum OS Version**: iOS 15.0
- **Device Support**: iPhone, iPad

### Capabilities
- **iCloud**: Enabled (CloudKit container: iCloud.com.gulfcoast.ProviderCalendar)
- **CloudKit**: Enabled
- **CloudKit Sharing**: Enabled
- **Background Modes**: Remote notifications

## Testing Notes

### TestFlight Testing
- **Internal Testing**: Test with clinic staff (5-10 users)
- **External Testing**: Limited external beta if needed
- **Beta App Review**: Required for external testing

### Testing Checklist
- [ ] App launches without crashes
- [ ] CloudKit share acceptance works
- [ ] Schedule data loads correctly
- [ ] Month navigation functions properly
- [ ] Print functionality works (PDFKit native)
- [ ] Offline viewing works with cached data
- [ ] All clinic location fields display correctly (OS, CL, OFF, CALL)
- [ ] Monthly notes display properly
- [ ] Works on various iPhone and iPad sizes
- [ ] Connection status indicators work
- [ ] Error messages are user-friendly
- [ ] No patient data displayed (verify with reviewers)

## Marketing Assets

### App Icon Requirements
- 1024x1024 pixels
- No transparency
- No rounded corners (iOS adds automatically)
- Should represent calendar/scheduling theme

### Screenshot Guidelines
- Show actual app interface
- Include sample provider names (not real patient data)
- Highlight key features:
  - Calendar view with location assignments
  - Monthly notes display
  - Month navigation
  - Print functionality
  - Connection status

## Release Notes

### Version 4.0.2 (Current)
- Fixed: App now opens to current month instead of old months
- Improved: Past months automatically hidden (only current/future displayed)
- Enhanced: Providers no longer need to scroll to find current assignments

### Version 4.0
- Major print system overhaul (CSS to PDFKit)
- Dynamic calendar sizing
- Improved performance

### Version 3.7.5
- Previous stable release
- CSS-based printing (deprecated in v4.0)

---

**Last Updated**: January 2026
**Status**: Ready for App Store Submission
