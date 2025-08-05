# GroundTruthLogger

This target is for the GroundTruthLogger prototype app - a manual event logging tool for creating ground truth data during train journeys.

## Build Commands

```zsh
# Build for simulator
xcodebuild -scheme GroundTruthLogger -destination "id=AE8D703E-E213-443C-8CBC-742F8807CCC3" -quiet

# Build without quiet flag (for debugging build errors)
xcodebuild -scheme GroundTruthLogger -destination "id=AE8D703E-E213-443C-8CBC-742F8807CCC3"
```