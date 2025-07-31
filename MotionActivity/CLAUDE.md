## Project Overview

This target produces a prototype app for viewing both live and historical Motion Activity entries using Core Motion to track activity while riding trains.

## CLI Commands

```zsh
# Build project
xcodebuild -project train-tracker-talk.xcodeproj -scheme "MotionActivity" -destination "platform=iOS Simulator,id=AE8D703E-E213-443C-8CBC-742F8807CCC3,arch=arm64" build -quiet
```