## Project Overview

This target produces a prototype app for collecting data about the usage of the CoreLocation significant location change API.

## CLI Commands

```zsh
# Build project
xcodebuild -project train-tracker-talk.xcodeproj -scheme "SignificantChange" -destination "platform=iOS Simulator,id=AE8D703E-E213-443C-8CBC-742F8807CCC3,arch=arm64" build -quiet
```