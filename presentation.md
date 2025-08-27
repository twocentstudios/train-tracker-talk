

# Let's Write a Train Tracking Algorithm

---

# Hi, I'm Chris

🇺🇸 From Chicago
🇯🇵 Japan for ~8 years

---

# Work History

- Timehop (SNS History)
- Cookpad (Cooking)
- twocentstudios (Indie)

^ TODO: app icons

---

# Let's Write a Train Tracking Algorithm

---

# Prerequisites

- Static railway data
- GPS data collected from an iPhone riding a train

---

# Static railway data

- Railways (e.g. JR Tokaido)
- Rail Directions (e.g. Northbound)
- Stations (e.g. JR Tokaido Shinagawa)
- RailwayCoordinate (Points that make up a Railway)

---

# Static railway data

^ Showing examples of railway, rail direction, station, railway coordinate on a map

---

# GPS data

- Sessions table
- Locations table

^ Showing raw database tables

---

# Location

^ Location has all data from CLLocation
^ Show annotated on map

---

# Session

^ Session is ordered list of Locations
^ Show annotated on map

---

# SessionViewer macOS app

^ walkthrough of SessionViewer mac app without RailwayTracker
^ sessions in sidebar
^ map on top, locations list on bottom

---

# Goal

1. Determine Railway
2. Determine Railway Direction
3. Determine Next/Current Station

---

# Example 1

- Railway: Toyoko Line
- Direction: Inbound (to Shibuya)
- Next station: Tsunashima

^ Show map of a point between two stations with nearby railways illustrated

---

1. **Determine Railway**
2. Determine Railway Direction
3. Determine Next/Current Station

---

# Railway Algorithm 1

- Find closest railway coordinates within 5km of Location
- Sort railways by nearest

---

# Railway Algorithm 1

^ Illustration

---

We did it!

However...

---

# Example 2

- Railway: Toyoko Line
- Direction: Outbound (to Yokohama)
- Next station: Hiyoshi

^ Show map of a point between two stations with nearby railways illustrated

---

# Problem

Toyoko Line and Meguro Line run parallel

---

# We need history

^ Show Locations on map starting from Nakameguro with both Toyoko and Meguro lines illustrated

---

# Railway Algorithm 2

- Convert nearby distance to score
- Add scores over time

---

# Railway Algorithm 2

^ Illustration

---

We did it!

However...

---

# Example 3

- Railway: Keihin-Tohoku Line
- Direction: Northbound
- Next station: Kamata

^ Show map of a point between two stations with nearby railways illustrated

---

Keihin-Tohoku Line ("Local") runs parallel to Tokaido Line ("Express")

^ Illustration

---

# Railway Algorithm 3

- Add penalty for passed stations
- Add penalty for stopping in-between stations

---

We did it!

There are many more edge cases but...

---

Let's move on!

---

1. Determine Railway
2. **Determine Railway Direction**
3. Determine Next/Current Station

---

Every Railway has 2 directions

---

^ Illustration: departure board Toyoko towards Shibuya, towards Yokohama

---

^ Illustration: map Toyoko towards Shibuya, towards Yokohama

---

# Example

- Railway: Toyoko Line
- Direction: Inbound (to Shibuya)
- Next station: Tsunashima

^ Show map of a point between two stations with nearby railways illustrated

---

# Direction Algorithm 1

- Store first nearby station for Railway
- Store second nearby station for Railway
- Compare order of first and second station

---

^ Illustration of Algorithm 1 using example

---

We did it!

However...

---

We must visit 2 stations in order to get a prediction...

---

Can we do better?

---

Use `Location.course`!

---

^ Illustration: location with course 0-360

---

# Direction Algorithm 2

- Fetch 2 closest stations to input location
- Calculate vector between 2 closest stations for "ascending" direction
- Calculate dot product between location course vector and closest stations vector
- Positive dot product == "ascending"
- Negative dot product == "descending"

---

^ Illustration of Algorithm 2 using example

---

Accumulate direction scores over time

---

We did it!

---

Let's move on!

---

1. Determine Railway
2. Determine Railway Direction
3. **Determine Next/Current Station**

---

^ heads up display in train car showing "Next"

---

- **Next**: Kawasaki
- **Approaching**: Kawasaki
- **Now**: Kawasaki
- **Next**: ...

---

^ Illustration of map showing approximate zones for each

---

Station proximity without history?

---

# Station Algorithm 1

- Calculate distance and direction from location to closest station S
- If distance < 200m 
	- "Now: S"
- If distance < 500m and direction is in travel direction
	- "Approaching: S"
- Else
	- "Next: S+1"

---

^ Illustration of map showing example "Now: S"

---

^ Illustration of map showing example "Approaching: S"

---

^ Illustration of map showing example "Next: S+1"

---

We did it!

However...

---

GPS data is unreliable

^ especially within big stations
^ especially when not moving

---

^ Illustration of map showing dead zone near Kawasaki

---

Let's create a history for each station

---

```swift
struct StationDirectionalLocationHistory {
    // Locations within 200 meters from station (date asc)
    var visitingLocations: [Location] = []

    // Locations within 500 directional meters from station but outside 200 meters (date asc)
    var approachingLocations: [Location] = []

    // First location that does not fall within visiting/approaching
    // or same as last visiting location if it's the last station on the line
    var firstDepartureLocation: Location?
}
```

---

^ Illustration: show 3-color binning for a station in SessionViewer with categories annotated

---

# Station Algorithm 2

- Phase 1: assign locations to stations
- Phase 2: update station phase history
- Phase 3: select most relevant station phase

---

# Phase 1: assign locations to stations

- Add each location to `visitingLocations` or `approachingLocations` for the closest station on each railway
- If there is no station history, add `firstDepartureLocation` to the closest station in opposite travel direction
- If a station has `visitingLocations` or `approachingLocations`, set a `firstDepartureLocation`
- If a location is stopped between stations, add it to `orphanedLocations` for the railway

---

# Phase 2: update station phase history

`visitingLocations` | `approachingLocations` | `firstDepartureLocation` | -> Phase
-|-|-|-
[]|[]|nil|departure
[]|[...]|nil|approaching
[...]|-|non-nil|visiting
[...]|-|non-nil|visited

---

# Phase 3: select most relevant station phase

- Find last station `S` in travel direction where `phase != nil`

Station Phase|Result
-|-
departure|Next: `S`+1
approaching|Approaching: `S`
visiting|Visiting: `S`
visited|Next: `S`+1

---

Station|Latest Phase
-|-
Tsurumi|Visited
Kawasaki|Visited

# Next: **Kamata**

---

Station|Latest Phase
-|-
Musashi-Kosugi|Visited
Motosumiyoshi|Approaching

# Approaching: **Motosumiyoshi**

---

We did it!

but can we distinguish "visited" and "passed"?

---

Train is **stopped** within station bounds for more than 20 seconds => `visited`

```swift
let earliestStoppedLocation = visitingLocations.first(where: { $0.speed <= 1.0 })
let latestStoppedLocation = visitingLocations.reversed().first(where: { $0.speed <= 1.0 })
latestStoppedLocation.timestamp.timeIntervalSince(earliestStoppedLocation.timestamp) > 20.0
```

---

Train is **moving** within station bounds for more than 70 seconds => `visited`

```swift
let earliestVisitedLocation = stationLocationHistory.visitingLocations.first
firstDepartureLocation.timestamp.timeIntervalSince(earliestVisitedLocation.timestamp) > 70.0
```

---

Else => `passed`

---

We did it!

---

TODO: Full demo of SessionViewer

---

This is open source!

github.com/twocentstudios/train-tracker-talk

^ TODO: QR Code

---

# Future Research

- Subway support
	- Custom ML Model for device velocity using accelerometer
	- Stairs counter to detect subway entrance
- Estimate exact train car from timetable
	- Show arrival times
	- Show next stop for express vs. local

^ TODO: blog post about other company's subway ML model

---

# Full version

- Eki Live on the App Store

^ TODO: QR Code

---

# Hire Me

- Freelance or full-time
- iOS generalist (not just train apps)
- twocentstudios.com

^ TODO: QR Code

