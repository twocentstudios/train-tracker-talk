## Project Overview

This macOS target provides a desktop viewer for examining database files created by the StartEndLocation iOS app. The app allows users to select and view train tracking session data, locations, and motion activities stored in the GRDB database files.

## Files used

- `data/railway.sqlite` - static database of railway info like Railway, Station, Coordinate, etc.
- `StartEndLocation/*` - opens databases created by `StartEndLocation` app and therefore uses its database schema.

## CLI Commands

```zsh
# Build project
xcodebuild -project train-tracker-talk.xcodeproj -scheme "SessionViewer" -destination "platform=macOS,arch=arm64" build -quiet
```