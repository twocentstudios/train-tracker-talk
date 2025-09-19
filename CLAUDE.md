## Project Overview

This is a repo for the Train Tracker conference talk for iOSDC. The repo showcases several prototype apps that are used in research and development for a theoretical production app that tracks a user's journey while riding trains in the Tokyo area.

## Targets

- `SignificantChange` - collects data to understand Core Location significant location change API.
- `SignificantStartLocation` - uses Core Location significant location change data to trigger collection of additional location data in the background.
- `MotionActivity` - views both live and historical Motion Activity entries using Core Motion to understand the device motion lifecycle as related to riding trains.
- `StartEndLocation` - automatically logs train journeys in the background.
- `SessionViewer` - view the data collected by `StartEndLocation` and process it with a tracking algorithm.

## Workflow

- ALWAYS check the CLAUDE.md file with each target directory for the proper build commands.
- ALWAYS build with xcodebuild with `-quiet` flag when a feature is complete. If the command returns errors you may run xcodebuild again without the `-quiet` flag.
- NEVER look in `DerivedData/` UNLESS you are looking at package documentation or trying to determine the cause of a build error.
- ALWAYS use the iPhone 16 Pro simulator on iOS 18.5 with UUID AE8D703E-E213-443C-8CBC-742F8807CCC3 (if it is unavailable, then alert me).
- ALWAYS run `xcodegen` when creating, moving, or deleting Swift files. The xcodeproj is generated from `project.yml`.
- NEVER write comments that are not timeless (e.g. `// I just updated this line`)

## Code guidelines

- Use the latest iOS 18 compatible SwiftUI APIs and techniques. Do research when necessary.

## Package Documentation

### Sharing-GRDB Documentation
- [SharingGRDB](./DerivedData/train-tracker-talk/SourcePackages/checkouts/sharing-grdb/Sources/SharingGRDB/Documentation.docc)
- [SharingGRDBCore](./DerivedData/train-tracker-talk/SourcePackages/checkouts/sharing-grdb/Sources/SharingGRDBCore/Documentation.docc)
- [StructuredQueriesGRDB](./DerivedData/train-tracker-talk/SourcePackages/checkouts/sharing-grdb/Sources/StructuredQueriesGRDB/Documentation.docc)
- [StructuredQueriesGRDBCore](./DerivedData/train-tracker-talk/SourcePackages/checkouts/sharing-grdb/Sources/StructuredQueriesGRDBCore/Documentation.docc)

### Swift Structured Queries Documentation
- [StructuredQueriesCore](./DerivedData/train-tracker-talk/SourcePackages/checkouts/swift-structured-queries/Sources/StructuredQueriesCore/Documentation.docc)

## CLI Commands

```zsh
# Generate xcodeproj file
xcodegen

# Format code before building
swiftformat . --exclude ./DerivedData --quiet
```
