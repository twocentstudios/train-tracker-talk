## Project Overview

This target produces a prototype app for automatically collecting location data during a train journey. Tracking starts conditionally in the background from each significant location returned from Core Location. Based on some heuristics, the app determines whether the device is on a train and, if so, begins tracking. More heuristics are used to determine when the train journey has ended and stop tracking.

## CLI Commands

```zsh
# Build project
xcodebuild -project train-tracker-talk.xcodeproj -scheme "StartEndLocation" -destination "platform=iOS Simulator,id=AE8D703E-E213-443C-8CBC-742F8807CCC3,arch=arm64" build -quiet
```