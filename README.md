# Schedule Viewer

A read-only iOS app that allows healthcare providers to view clinic schedules created by administrators using the Doctor-Schedule-Calendar app.

## Overview

Schedule Viewer is a companion app designed for medical clinics where administrators create and manage schedules using the Doctor-Schedule-Calendar app. This viewer app allows doctors and other healthcare providers to access their schedules from their personal devices while at work or away from the clinic.

## Features

- **Read-Only Schedule Viewing**: View appointments and schedules without editing capabilities
- **Multi-Device Support**: Optimized for both iPhone and iPad
- **iCloud Integration**: Seamlessly syncs with data created by the Doctor-Schedule-Calendar app
- **Date Navigation**: Easy date selection and navigation
- **Doctor Filtering**: Filter appointments by specific doctors
- **Responsive Design**: Adaptive layouts for different screen sizes
- **Offline Support**: View cached data when offline

## Requirements

- iOS 15.0 or later
- iPhone or iPad
- iCloud account with access to shared schedule data
- Internet connection for initial data sync

## Installation

### For Users
1. Download from the App Store
2. Sign in with your iCloud account
3. Grant necessary permissions for iCloud data access
4. Start viewing your schedule

### For Developers
1. Clone the repository
2. Open `ScheduleViewer.xcodeproj` in Xcode
3. Configure your development team and bundle identifier
4. Build and run on device or simulator

## Architecture

### Data Model
The app uses Core Data with CloudKit integration to sync with the administrator's schedule data:

- **Appointment**: Individual appointment records with patient, doctor, time, and status
- **Doctor**: Doctor information and relationships to appointments
- **ScheduleSettings**: Clinic-wide settings and configuration

### Key Components

- **ScheduleView**: Main view with adaptive layouts for iPhone/iPad
- **ScheduleViewModel**: Business logic and data management
- **PersistenceController**: Core Data and CloudKit integration
- **AppointmentRowView**: Individual appointment display component

## iCloud Configuration

The app is configured to read data from the administrator's iCloud container. Key configuration:

```xml
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.yourcompany.scheduleviewer</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>Schedule Viewer</string>
    </dict>
</dict>
```

## Privacy and Security

- **Read-Only Access**: No modification capabilities to protect data integrity
- **iCloud Security**: Leverages Apple's iCloud security infrastructure
- **No Personal Data Collection**: App does not collect or store personal user data
- **HIPAA Compliant**: Designed with healthcare privacy requirements in mind

## App Store Submission

### Required Metadata
- **App Name**: Schedule Viewer
- **Category**: Medical
- **Age Rating**: 4+ (No objectionable content)
- **Languages**: English
- **Devices**: iPhone, iPad

### Privacy Policy Requirements
- No data collection
- iCloud data access for schedule viewing
- No third-party analytics or tracking

### Screenshots Required
- iPhone (6.7" and 5.5")
- iPad (12.9" and 11")

## Development Notes

### Testing
- Test on both iPhone and iPad simulators
- Verify iCloud data sync functionality
- Test offline viewing capabilities
- Validate date filtering and doctor filtering

### Build Configuration
- Enable CloudKit capabilities in Xcode
- Configure proper bundle identifier
- Set up App Store Connect record
- Configure code signing and provisioning

## Support

For technical support or questions about the app, please contact the development team.

## License

This app is proprietary software developed for medical clinic use.

## Version History

- **1.0**: Initial release with basic schedule viewing functionality
- Support for iPhone and iPad
- iCloud integration with Doctor-Schedule-Calendar app
- Date navigation and doctor filtering 