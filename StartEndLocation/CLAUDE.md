## Project Overview

This target produces a prototype app for automatically collecting location data during a train journey. Tracking starts conditionally in the background from each significant location returned from Core Location. Based on some heuristics, the app determines whether the device is on a train and, if so, begins tracking. More heuristics are used to determine when the train journey has ended and stop tracking.

## RootStore Rules

**Session Lifecycle:**
1. **Trigger**: Significant location change → create session → check motion history (5min)
2. **Timeout Logic**: Automotive=5m, Walking/Cycling=1m, Stationary=immediate close
3. **Train Detection**: 3+ locations with speed ≥6.0 m/s → mark `isOnTrain=true`
4. **Stop Conditions**: Walking detected OR 5min without high speed → end session

**States**: Waiting → Evaluating (with timeout) → Collecting (until stop condition)

**Data**: All motion activities and locations written to database with `sessionID`

## CLI Commands

```zsh
# Build project
xcodebuild -project train-tracker-talk.xcodeproj -scheme "StartEndLocation" -destination "platform=iOS Simulator,id=AE8D703E-E213-443C-8CBC-742F8807CCC3,arch=arm64" build -quiet
```