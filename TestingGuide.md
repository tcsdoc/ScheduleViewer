# ScheduleViewer Testing Guide

## Overview
This guide provides comprehensive testing procedures for ScheduleViewer before App Store submission. The app is a **provider work schedule viewer** that displays which healthcare providers are working at which clinic locations on any given day.

## ⚠️ Critical Understanding

**WHAT THIS APP SHOWS:**
- Provider work location assignments (Ocean Springs, Cedar Lake)
- Which providers are off duty
- Which provider is on-call
- Monthly clinic notes

**WHAT THIS APP DOES NOT SHOW:**
- ❌ Patient appointments
- ❌ Patient information
- ❌ Appointment times or statuses
- ❌ Any PHI (Protected Health Information)

**Field Definitions:**
- **OS** = Ocean Springs clinic location (shows which provider works there)
- **CL** = Cedar Lake clinic location (shows which provider works there)
- **OFF** = Providers who are off duty
- **CALL** = Provider who is on-call

---

## Pre-Testing Setup

### Required Equipment
- iPhone (various sizes: SE, 12, 14 Pro Max, 15 Pro)
- iPad (various sizes: 11", 12.9")
- Mac with Xcode 15+
- iCloud account with test schedule data
- TestFlight account for beta testing

### Test Data Requirements
**FROM PROVIDER SCHEDULE CALENDAR (PSC):**
- Sample provider schedules created by PSC admin
- Multiple provider names assigned to different locations
- Various schedule patterns (rotating providers between OS/CL)
- Monthly notes with holidays or schedule changes
- At least 3-6 months of test data

**SETUP IN PSC:**
- Create test schedules with provider names in OS/CL fields
- Add some days with providers OFF
- Designate CALL providers
- Add monthly notes for testing
- Create CloudKit share and email to test device

---

## Functional Testing

### 1. App Launch and Initial Setup

**Test Cases:**
- [ ] App launches without crashes
- [ ] Launch screen displays correctly
- [ ] "Setup Required" prompt appears on first launch
- [ ] "Add Share" button is visible
- [ ] Connection status shows "No Data" before share acceptance

**Test Steps:**
1. Install app on clean device (delete if previously installed)
2. Launch app
3. Verify "Setup Required" message displays
4. Verify no schedule data shown initially
5. Note connection status indicator

**Expected Results:**
- Clean launch with no crashes
- Clear prompt to add CloudKit share
- No data displayed until share accepted

---

### 2. CloudKit Share Acceptance

**Test Cases:**
- [ ] Share input sheet opens when "Add Share" tapped
- [ ] URL paste field accepts CloudKit share URL
- [ ] "Accept Share" button disabled when field empty
- [ ] Share acceptance shows loading indicator
- [ ] Success: Data loads and sheet dismisses
- [ ] Error: User-friendly error message displays

**Test Steps:**
1. Tap "Add Share" button
2. Input sheet should open
3. Paste valid CloudKit share URL from PSC
4. Tap "Accept Share"
5. Wait for processing
6. Verify data loads

**Valid Test URL Format:**
```
https://www.icloud.com/share/[shareID]
```

**Test Scenarios:**
- Valid share URL (should succeed)
- Invalid URL format (should show error)
- Network disconnected (should show error)
- User not signed into iCloud (should show error)

**Expected Results:**
- Share acceptance succeeds with valid URL
- Schedule data loads and displays
- Error messages are clear and actionable
- UserDefaults persists accepted share

---

### 3. Schedule Data Display

**Test Cases:**
- [ ] Monthly schedule displays in calendar format
- [ ] Provider names appear in correct fields (OS, CL, OFF, CALL)
- [ ] Dates are formatted correctly
- [ ] Monthly notes display when present
- [ ] Empty days show appropriately
- [ ] Multiple providers in one field display correctly

**Test Steps:**
1. After share acceptance, view loaded schedules
2. Check current month displays
3. Verify provider names in location fields
4. Check monthly notes section
5. Verify date formatting

**Data to Verify:**
```
Date: [Month Day, Year]
OS: [Provider name(s) at Ocean Springs]
CL: [Provider name(s) at Cedar Lake]
OFF: [Provider name(s) who are off]
CALL: [Provider name on-call]
```

**Expected Results:**
- All schedule entries display correctly
- Location labels (OS, CL) are clear
- Provider names are readable
- No truncation of important data

---

### 4. Month Navigation

**Test Cases:**
- [ ] Current month displays on launch
- [ ] Month name shows in header
- [ ] Left arrow navigates to previous month
- [ ] Right arrow navigates to next month
- [ ] Arrows disable at data boundaries
- [ ] Month changes update displayed schedules

**Test Steps:**
1. Note current month displayed
2. Tap left arrow (previous month)
3. Verify schedule updates
4. Tap right arrow (next month)
5. Navigate through multiple months
6. Test at earliest/latest data boundaries

**Expected Results:**
- Smooth month transitions
- Correct month name displayed
- Only months with data are accessible
- Navigation arrows enable/disable appropriately

---

### 5. Monthly Notes Display

**Test Cases:**
- [ ] Monthly notes section appears when notes exist
- [ ] Notes text displays completely
- [ ] Multiple note lines show separately
- [ ] Notes format correctly (no overflow)
- [ ] Months without notes don't show empty section

**Test Steps:**
1. Navigate to month with monthly notes
2. Verify "Monthly Notes" header appears
3. Read all note lines
4. Navigate to month without notes
5. Verify notes section doesn't appear

**Expected Results:**
- Notes display in green-tinted section
- All note lines readable
- Clean separation from schedule entries
- No empty notes sections

---

### 6. Data Refresh

**Test Cases:**
- [ ] Pull-to-refresh gesture works
- [ ] Loading indicator appears during refresh
- [ ] Updated data loads from CloudKit
- [ ] Current month view maintained after refresh
- [ ] Error handling if refresh fails

**Test Steps:**
1. Pull down on schedule view
2. Observe loading indicator
3. Wait for refresh completion
4. Verify data updates (if changes exist in PSC)
5. Test refresh with no network connection

**Expected Results:**
- Smooth pull-to-refresh animation
- Data refreshes from CloudKit
- Error message if refresh fails
- Current month view preserved

---

### 7. Print Functionality (v4.0 PDFKit)

**Test Cases:**
- [ ] Print button appears in header
- [ ] Tapping print opens iOS print dialog
- [ ] PDF preview shows calendar layout
- [ ] Calendar grid displays correctly
- [ ] Provider names appear in day cells
- [ ] Monthly notes included on PDF
- [ ] Page layout fits US Letter size
- [ ] Dynamic week sizing works (4-6 weeks)

**Test Steps:**
1. Tap "Print" button in header
2. Verify iOS print dialog opens
3. Preview PDF output
4. Check calendar grid layout
5. Verify provider assignments visible in cells
6. Test with months of different lengths:
   - February (4 weeks)
   - Short months (5 weeks)
   - Long months (6 weeks)
7. Send to printer or save PDF

**PDF Layout Verification:**
- Month title at top
- Monthly notes (if present) below title
- Weekday headers (Sun-Sat)
- Calendar grid with:
  - Day numbers
  - OS: [provider]
  - CL: [provider]
  - OFF: [provider]
  - CALL: [provider]

**Expected Results:**
- Professional PDF output
- All content fits on single page per month
- Text is readable (no excessive shrinking)
- Monochrome output suitable for printing
- No content overflow or cut-off

---

### 8. Connection Status Indicators

**Test Cases:**
- [ ] "Loading..." shows during data fetch
- [ ] "Connected" shows with green check when data loaded
- [ ] "Connection Issue" shows with warning when CloudKit unavailable
- [ ] "No Data" shows when no schedules loaded
- [ ] Status updates appropriately with network changes

**Test Steps:**
1. Launch app and observe loading state
2. Wait for data load and observe "Connected"
3. Disable network and restart app
4. Observe "Connection Issue"
5. Re-enable network and refresh
6. Verify status updates

**Expected Results:**
- Clear visual indication of connection state
- Users understand app status at a glance
- Appropriate colors (green=good, red=problem, gray=no data)

---

## UI/UX Testing

### 1. iPhone Layout Testing

**Test Devices:**
- iPhone SE (smallest screen)
- iPhone 14 Pro (standard)
- iPhone 15 Pro Max (largest screen)

**Test Cases:**
- [ ] Header section displays completely
- [ ] Month navigation buttons accessible
- [ ] Schedule entries readable
- [ ] Print button accessible
- [ ] Connection status visible
- [ ] Safe area margins respected (notch/Dynamic Island)
- [ ] Portrait orientation optimal
- [ ] Landscape orientation functional

**Test Steps:**
1. Test app on each iPhone size
2. Verify all UI elements fit on screen
3. Check text readability
4. Test touch targets (minimum 44x44 points)
5. Rotate to landscape and verify layout

**Expected Results:**
- Clean layout on all iPhone sizes
- No UI element overlap
- Text is readable without zooming
- Touch targets are easily tappable

---

### 2. iPad Layout Testing

**Test Devices:**
- iPad 11"
- iPad Pro 12.9"

**Test Cases:**
- [ ] Layout utilizes larger screen appropriately
- [ ] Text scales well for reading distance
- [ ] Calendar entries are spacious
- [ ] Print preview looks professional
- [ ] Split-screen multitasking works
- [ ] All orientations supported

**Test Steps:**
1. Launch app on iPad
2. Verify layout uses screen space effectively
3. Test in all orientations
4. Test split-screen with another app
5. Verify print output

**Expected Results:**
- Professional appearance on iPad
- Layout adapts to larger screen
- Works in all orientations
- Multitasking doesn't break layout

---

### 3. Accessibility Testing

**Test Cases:**
- [ ] VoiceOver reads all elements correctly
- [ ] Dynamic Type (text sizing) supported
- [ ] High contrast mode supported
- [ ] Reduce motion respected
- [ ] All buttons have accessibility labels
- [ ] Color is not only indicator (text labels present)

**Test Steps:**
1. Enable VoiceOver (Settings > Accessibility > VoiceOver)
2. Navigate app with VoiceOver
3. Verify all elements announced correctly
4. Change text size (Settings > Display & Brightness > Text Size)
5. Verify layout adjusts without breaking
6. Enable high contrast and check readability
7. Enable reduce motion and check animations

**Expected Results:**
- Full VoiceOver support
- Layout adapts to larger text sizes
- High contrast improves visibility
- No essential information conveyed by color alone

---

## Performance Testing

### 1. App Launch Performance

**Test Cases:**
- [ ] Cold launch < 3 seconds
- [ ] Warm launch < 1 second
- [ ] Initial data load < 5 seconds (normal network)
- [ ] No excessive memory usage
- [ ] No memory leaks after extended use

**Test Steps:**
1. Force quit app completely
2. Launch app and time until usable
3. Background and relaunch (warm launch)
4. Monitor memory usage in Xcode Instruments
5. Use app for extended period and check memory

**Expected Results:**
- Fast launch times
- Memory usage stays reasonable (< 50MB typical)
- No memory leaks detected
- Smooth operation even after hours of use

---

### 2. Network Performance Testing

**Test Scenarios:**
- [ ] Fast WiFi (optimal conditions)
- [ ] Slow WiFi (< 1 Mbps)
- [ ] Cellular data (4G/5G)
- [ ] Intermittent connection (switching networks)
- [ ] No connection (offline mode)

**Test Steps:**
1. Test share acceptance on fast WiFi
2. Test data refresh on slow WiFi
3. Switch to cellular and test refresh
4. Enable airplane mode and test offline viewing
5. Switch networks during data fetch

**Expected Results:**
- Works on all connection types
- Handles slow connections gracefully
- Offline viewing works with cached data
- Network interruptions handled without crashes
- User-friendly messages for network issues

---

### 3. Data Volume Testing

**Test Cases:**
- [ ] Handles 12+ months of schedule data
- [ ] Smooth scrolling with large datasets
- [ ] Quick month navigation with lots of data
- [ ] Print generation time reasonable (< 5 seconds per month)
- [ ] Memory usage reasonable with large datasets

**Test Steps:**
1. Load PSC with 12+ months of schedules
2. Accept share in ScheduleViewer
3. Wait for all data to load
4. Navigate through all months
5. Test print functionality
6. Monitor app responsiveness

**Expected Results:**
- Handles multiple months of data efficiently
- No lag or stuttering when navigating
- Print generation completes in reasonable time
- Memory usage stays under control

---

## Security & Privacy Testing

### 1. Data Access Verification

**Test Cases:**
- [ ] App is truly read-only (no write operations)
- [ ] Cannot modify schedules from app
- [ ] Cannot delete schedule entries
- [ ] No patient data accessed or displayed
- [ ] Only shared zone data accessible

**Test Steps:**
1. Verify no edit buttons or fields exist in UI
2. Attempt to modify data (should be impossible)
3. Review CloudKit operations (read-only queries only)
4. Verify no PHI (patient information) in any view
5. Check that only shared CloudKit zone is accessed

**Expected Results:**
- Zero ability to modify data
- All CloudKit operations are read-only
- No patient information visible anywhere
- Only provider work schedules displayed

---

### 2. Privacy Compliance

**Test Cases:**
- [ ] No analytics or tracking code
- [ ] No third-party SDKs
- [ ] No data sent to external servers
- [ ] iCloud data encrypted in transit
- [ ] No sensitive data in logs

**Test Steps:**
1. Review code for analytics libraries (should be none)
2. Monitor network traffic (should only be iCloud.com)
3. Review console logs for sensitive data
4. Verify all CloudKit communication is encrypted
5. Check Info.plist privacy declarations

**Expected Results:**
- Zero third-party tracking
- Only Apple iCloud communication
- No sensitive data exposed in logs
- All data encrypted in transit
- Privacy policy accurate

---

## CloudKit Integration Testing

### 1. Share Acceptance Flow

**Test Cases:**
- [ ] Accept share with valid URL
- [ ] Reject invalid share URL
- [ ] Handle already-accepted share
- [ ] Handle revoked share gracefully
- [ ] Persist accepted share through app restart

**Test Steps:**
1. Accept fresh share URL → should succeed
2. Try invalid URL → should show clear error
3. Accept same share again → should handle gracefully
4. Admin revokes share in PSC → app should show error on refresh
5. Restart app → shared data should still be accessible

**Expected Results:**
- Clean share acceptance flow
- Good error messages
- Persistence works correctly
- Graceful handling of edge cases

---

### 2. Zone Discovery and Data Sync

**Test Cases:**
- [ ] Discovers shared zones on launch
- [ ] Fetches schedule records with pagination
- [ ] Fetches monthly note records
- [ ] Handles empty zones (no data)
- [ ] Removes duplicate records correctly

**Test Steps:**
1. Check debug logs for zone discovery
2. Verify pagination works with large datasets
3. Confirm monthly notes fetch separately
4. Test with empty shared zone
5. Check duplicate handling (keeps most complete record)

**Expected Results:**
- All shared zones discovered
- All records fetched (even thousands)
- Pagination works transparently
- Duplicates resolved intelligently

---

### 3. Offline and Sync Testing

**Test Cases:**
- [ ] Cached data viewable offline
- [ ] Refresh fails gracefully when offline
- [ ] Sync resumes when connection restored
- [ ] No data loss when going offline
- [ ] Clear indication of offline status

**Test Steps:**
1. Load schedules while online
2. Enable airplane mode
3. Quit and relaunch app
4. Verify cached data displays
5. Try to refresh (should show error)
6. Restore connection and refresh (should succeed)

**Expected Results:**
- Offline viewing works perfectly
- Users know when offline
- Data syncs when connection returns
- No crashes or data corruption

---

## Device-Specific Testing Matrix

### iPhone Models
| Device | iOS Version | Screen Size | Status | Notes |
|--------|-------------|-------------|---------|-------|
| iPhone SE (2nd/3rd gen) | 15.0+ | 4.7" | ☐ | Smallest screen |
| iPhone 12 | 15.0+ | 6.1" | ☐ | Standard size |
| iPhone 14 Pro | 16.0+ | 6.1" | ☐ | Dynamic Island |
| iPhone 15 Pro Max | 17.0+ | 6.7" | ☐ | Largest screen |

### iPad Models
| Device | iOS Version | Screen Size | Status | Notes |
|--------|-------------|-------------|---------|-------|
| iPad (9th gen) | 15.0+ | 10.2" | ☐ | Base model |
| iPad Air | 15.0+ | 10.9" | ☐ | Mid-range |
| iPad Pro 11" | 15.0+ | 11" | ☐ | Pro model |
| iPad Pro 12.9" | 15.0+ | 12.9" | ☐ | Largest screen |

---

## TestFlight Beta Testing

### Internal Testing (Clinic Staff)

**Test Group:** 5-10 clinic providers

**Test Objectives:**
- Verify real-world usage
- Test with actual clinic schedules
- Gather usability feedback
- Identify workflow issues

**Feedback Areas:**
- Is schedule display clear and easy to read?
- Are clinic location labels (OS, CL) obvious?
- Is month navigation intuitive?
- Is print output useful?
- Any missing features needed?

**Test Duration:** 1-2 weeks

---

### External Testing (If Needed)

**Test Group:** Limited external beta (optional)

**Requirements:**
- Must have CloudKit share from PSC admin
- Must be invited to TestFlight
- Must provide structured feedback

**Test Focus:**
- UI/UX on various devices
- Performance testing
- Edge case discovery
- Crash reporting

---

## App Store Submission Checklist

### Pre-Submission Requirements
- [ ] All critical bugs fixed
- [ ] Performance testing passed
- [ ] Security review completed
- [ ] Accessibility testing passed
- [ ] TestFlight testing successful with real users
- [ ] Screenshots captured for all device sizes
- [ ] App description accurately reflects functionality
- [ ] Privacy policy reviewed and accurate
- [ ] **Emphasis: NO patient data - this must be clear to Apple reviewers**

### Build Configuration
- [ ] Release build created in Xcode
- [ ] Version number updated (4.0.1)
- [ ] Build number incremented (3)
- [ ] Code signing with production certificate
- [ ] Archived build validated
- [ ] Uploaded to App Store Connect

### Metadata Complete
- [ ] App name: "ScheduleViewer"
- [ ] Subtitle: Provider work schedule viewer
- [ ] Description emphasizes: WORK SCHEDULES not patient appointments
- [ ] Keywords include: provider schedule, work schedule, clinic locations
- [ ] Screenshots show provider location assignments
- [ ] Privacy policy URL active and accurate

### For App Review Team
**Critical Notes to Include:**
```
IMPORTANT FOR APP REVIEWERS:

This app displays PROVIDER WORK SCHEDULES showing which healthcare
providers are working at which clinic locations. It does NOT show
patient appointments or patient information.

Fields shown:
- OS (Ocean Springs): Provider working at Ocean Springs clinic
- CL (Cedar Lake): Provider working at Cedar Lake clinic  
- OFF: Providers who are off duty
- CALL: Provider who is on-call

NO PATIENT DATA is accessed, displayed, or stored by this app.

Test share URL will be provided for review testing.
```

---

## Bug Reporting Template

### Bug Report Format
```
Title: [Brief description]

Device: [iPhone/iPad model]
iOS Version: [Version number]
App Version: 4.0.1 (Build 3)

Steps to Reproduce:
1. [First step]
2. [Second step]
3. [Third step]

Expected Result:
[What should happen]

Actual Result:
[What actually happened]

Screenshots/Videos:
[Attach if helpful]

Additional Context:
[Any other relevant information]

Severity:
[ ] Critical (crashes, data loss)
[ ] High (major feature broken)
[ ] Medium (feature works but has issues)
[ ] Low (cosmetic or minor)
```

---

## Known Issues & Limitations

### Current Limitations
1. **Zone Discovery**: Accepts ALL shared zones (no filtering by name)
2. **Share Management**: No UI to view/remove accepted shares
3. **Version Display**: Hardcoded fallback version "3.7.5" in code (should be 4.0.1)
4. **Private Database Query**: Queries private DB in addition to shared DB (may be unnecessary for read-only app)

### Areas for Future Enhancement
- Share management UI (view/remove accepted shares)
- Filter zone discovery by zone name for security
- Clear cached data / reset app option
- Search/filter providers by name
- Export schedules to native Calendar app

---

## Emergency Procedures

### Critical Issue After Release

If critical bugs found post-release:
1. **Assess severity** (crashes, data loss, security)
2. **Pull from sale** if necessary (App Store Connect)
3. **Fix in development** immediately
4. **Submit hotfix** with expedited review request
5. **Notify users** via TestFlight or email if needed

### CloudKit Share Issues

If users report share acceptance problems:
1. **Verify PSC share settings** (.readOnly permission)
2. **Check CloudKit container status** (iCloud dashboard)
3. **Test share URL** on clean device
4. **Verify entitlements** (cloudkit-share-handling present)
5. **Update app** if entitlement change needed

---

## Support Resources

### For Testers
- FAQ document (to be created)
- Troubleshooting guide (to be created)
- Admin contact for share URL issues

### For Developers
- README.md (comprehensive technical docs)
- CloudKit dashboard monitoring
- Xcode Instruments for performance analysis
- TestFlight crash reports

---

**Document Version**: 2.0 (Updated for v4.0 - Provider Schedule Focus)  
**Last Updated**: January 2026  
**Next Review**: After App Store submission feedback
