# Let's Write a Train Tracking Algorithm

Chris Trott
iOSDC 2025/09/20

^ Welcome to my talk.

---

# Hi, I'm Chris

🇺🇸 From Chicago
🇯🇵 Japan for ~8 years

^ My name is Chris Trott.
^ I'm an iOS Engineer originally from Chicago.
^ I've lived and worked in Japan for 8 years.

---

# Work History

- Timehop (SNS History)
- Cookpad (Cooking)
- twocentstudios (Indie)

^ I worked at a startup called Timehop in New York City.
^ I worked at Cookpad for 6 years.
^ Since then, I've been working on my own apps in the App Store.
^ TODO: app icons

---

# Let's Write a Train Tracking Algorithm

^ Lately I've been working on an app called Eki Live.
^ Today I'm going to talk about a part of that app.

---

# What is a train tracking algorithm?

^ What do I mean by train tracking algorithm?
^ Well, when riding a train, it's useful to know the upcoming station.

---

[Illustration of door display]

^ On the train, we can see the train information display (案内表示器) or listen for announcements.

---

[illustration of train moving between stations showing NEXT, SOON, NOW as it moves]

^ Would it be useful to see this information in your Dynamic Island?

---

# Prerequisites

- Static railway data
- Live GPS data from an iPhone on a train

^ We need two types of data for the train tracking algorithm

---

# Static railway data

- Railways (e.g. JR Tokaido)
- Stations (e.g. JR Tokaido Shinagawa)
- Railway Directions (e.g. Northbound)
- RailwayCoordinate (Points that make up a Railway)

[Showing examples of railway, rail direction, station, railway coordinate on a map]

^ Railways are ordered groups of Stations.
^ Trains travel in both Directions on a Railway.
^ Coordinates make up the path of a Railway's physical tracks.

---

# GPS data

- Sessions table
- Locations table

[Showing raw database tables]

^ We collect live GPS data using the Core Location framework.

---

# Location

[Show annotated on map]

^ A Location has all data from CLLocation.
^ Latitude, longitude, speed, course, accuracy.

---

# Session

[Show annotated on map]

^ A Session is an ordered list of Locations.
^ A Session represents a possible journey.

---

# SessionViewer macOS app

[walkthrough of SessionViewer mac app without RailwayTracker]

^ I created a macOS app to visualize the raw data.
^ In the left sidebar there is a list of Sessions.
^ In the top panel there is map.
^ In the bottom panel there is a list of ordered Locations for a Session.
^ Clicking on a Location shows its position and course on the map.
^ The arrow color is green for fast and red for stopped.

---

# Goal

1. Determine Railway
2. Determine Railway Direction
3. Determine Next/Current Station Phase

^ Our goal is to make an algorithm that determines 3 types of information:
^ The railway, the direction of the train, and the next or current station.

---

[Illustration of flowchart]

^ The app channels Location values to the algorithm.
^ The algorithm updates its understanding of the device's location in the world.
^ The algorithm calculates a new set of railway, direction, station phase.

---

# Example

- Railway: Toyoko Line
- Direction: Inbound (to Shibuya)
- Next station: Tsunashima

[Show map of a point between two stations with nearby railways illustrated]

^ Let's start with a single Location.
^ To capture this point, the iPhone was on the Toyoko Line.
^ The iPhone was heading towards Shibuya.
^ The iPhone was between Okurayama station and Tsunashima station.

---

1. **Determine Railway**
2. Determine Railway Direction
3. Determine Next/Current Station

^ Can we determine the Railway from this Location?

---

# Railway Algorithm V1

- Find closest railway coordinates within 5km of Location
- Sort railways by nearest

^ First, we find the closest RailwayCoordinate for each Railway within 5 kilometers of the Location.
^ Finally, we order the railways by which RailwayCoordinate is closest.

---

[Illustration with Toyoko Line and Shin-Yokohama Lines]

^ The closest RailwayCoordinate is the Toyoko Line is only about N meters away.
^ The next closest RailwayCoordinate is the Shin-Yokohama Line about M meters away.

---

We did it!

However...

^ Our algorithm works well for this case but...

---

# Example

- Railway: Toyoko Line
- Direction: Outbound (to Yokohama)
- Next station: Hiyoshi

[Show map of a point between two stations with nearby railways illustrated]

^ Let's consider another Location.
^ This Location was also captured on the Toyoko Line.

---

# Problem

Toyoko Line and Meguro Line run parallel

^ But in this section of the railway track, the Toyoko Line and Meguro Line run parallel.
^ It's not possible to determine whether the correct line is Toyoko or Meguro from just this one Location.

---

# We need history

[Show Locations on map starting from Nakameguro with both Toyoko and Meguro lines illustrated]

^ The algorithm needs to use all Locations from the journey.

---

# Railway Algorithm V2

- Convert nearby distance to score
- Add scores over time

^ First, we convert the distance between the Location and the nearest railway coordinate to a score
^ The score is high if close and exponentially lower when far.
^ Then, we add the scores over time.

---

# Railway Algorithm V2

[Illustration with SessionViewer]

^ The score from Nakameguro to Hiyoshi is much higher for the Toyoko Line than the Meguro Line.

---

We did it!

However...

^ Our algorithm works well for this case but...

---

# Example 3

- Railway: Keihin-Tohoku Line
- Direction: Northbound
- Next station: Kamata

[Show map of a point between two stations with nearby railways illustrated]

^ Let's consider a third Location.
^ This Location was captured on the Keihin-Tohoku Line which runs the east corridor of Tokyo.

---

Keihin-Tohoku Line ("Local") runs parallel to Tokaido Line ("Express")

[Illustration]

^ Several lines run parallel in this corridor.
^ The Tokaido Line follows the same track as the Keihin-Tohoku Line
^ But the Tokaido Line skips many stations.

---

[Illustration]

^ If we only compare railway coordinate proximity scores, the scores will be the same.

---

# Railway Algorithm V3

- Add penalty for passed stations
- Add penalty for stopping in-between stations

[Illustration]

^ Let's add a small penalty to the score if a station is passed.
^ If a station is passed, that indicates the iPhone may be on an express train.
^ Let's add a small penalty to the score if a train stops between stations.
^ If a train stops between stations, that indicates the iPhone may be on a local train.

---

[Illustration]

^ The Keihin-Tohoku score is now slightly larger than the Tokaido score.

---

We did it!

There are many more edge cases but...

^ Our algorithm works well for this case.
^ But there are many more edge cases.

---

Let's move on!

^ However, let's continue.

---

1. Determine Railway
2. **Determine Railway Direction**
3. Determine Next/Current Station

^ For each potential railway, we will determine which direction the train is moving.

---

Every Railway has 2 directions

^ Every railway has 2 directions.

---

[Illustration: departure board Toyoko towards Shibuya, towards Yokohama]

^ We always see separate timetables on the departure board.

---

[Illustration: map Toyoko towards Shibuya, towards Yokohama

^ For example, the Toyoko Line goes inbound towards Shibuya and outbound towards Yokohama.

---

# Example

- Railway: Toyoko Line
- Direction: Inbound (to Shibuya)
- Next station: Tsunashima

[Show map of a point between two stations with nearby railways illustrated]

^ Let's consider a Location captured on the Toyoko Line going inbound to Shibuya.

---

# Direction Algorithm V1

- Store first nearby station for Railway
- Store second nearby station for Railway
- Compare order of first and second station

^ Once we have visited two stations, we can compare the order of the stations.
^ If the order of the stations matches the order of the stations in the database, the iPhone is heading in the "ascending" direction.

---

[Illustration of Algorithm 1 using example]

^ Since the iPhone visited Okurayama then Tsunashima, we know they are heading inbound to Shibuya.

---

We did it!

However...

^ Our algorithm works well for this case but...

---

We must visit 2 stations in order to get a prediction...

^ It could take 5 minutes to determine the train direction.

---

Can we do better?

^ Can we do better?

---

Use `Location.course`!

^ Let's use the Location's course.

---

[Illustration: location with course 0-360]

^ Core Location provides an estimate of the iPhone's course in degrees.
^ 0 degrees means North
^ 180 degrees means South

---

# Direction Algorithm V2

- Fetch 2 closest stations to input location
- Calculate vector between 2 closest stations for "ascending" direction
- Calculate dot product between location course vector and closest stations vector
- Positive dot product == "ascending"
- Negative dot product == "descending"

^ First, we find the 2 closest stations to the Location
^ Next, we calculate the vector between the 2 closest stations for the "ascending" direction in our database.
^ Next, we calculate the dot product between the Location's course vector and the stations vector.
^ If the dot product is positive, then the railway direction is "ascending"
^ If the dot product is negative, then the railway direction is "descending"

---

[Illustration of Algorithm 2 using example]
[Split up the previous slide into separate illustrations for each step]

---

We did it!

^ Our algorithm works well.

---

Let's move on!

^ Let's move on to the last part.

---

1. Determine Railway
2. Determine Railway Direction
3. **Determine Next/Current Station**

^ Finally, we can determine the next station.

---

[heads up display in train car showing "Next"]

^ The next station is shown on the train information display (案内表示器)

---

- **Next**: Kawasaki
- **Soon**: Kawasaki
- **Now**: Kawasaki
- **Next**: ...

^ The display cycles through next, soon, and now for each station.

---

[Illustration of map showing approximate zones for each]

^ On a map, here is where each display is shown.

---

# Station Algorithm V1

- Calculate distance `d` from Location to closest station `S`
- Calculate direction `c` from Location to closest station `S`

Case|Result
-|-
`d` < 200m|"Now: `S`"
`d` < 500m && `c` > 0|"Soon: `S`"
`c` > 0|"Next: `S`"
else|"Next: `S+1`"

---

[Illustration of map showing example "Now: S"]

^ A Location less than 200m from the station

---

[Illustration of map showing example "Approaching: S"]

^ A Location less than 500m from the station in the travel direction

---

[Illustration of map showing example "Next: S"]

^ A Location in the travel direction

---

[Illustration of map showing example "Next: S+1"]

^ A Location not in the travel direction

---

We did it!

However...

^ Our algorithm works well but...

---

GPS data is unreliable

^ GPS data is unreliable.
^ Especially within big stations.
^ Especially when not moving.

---

[Illustration of map showing dead zone near Kawasaki]

^ Here is an example near Kawasaki station

---

Let's create a history for each station

^ Let's use history again.

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

^ For each station, let's categorize each Location according to its distance and direction.

---

[Illustration: show 3-color binning for a station in SessionViewer with categories annotated]

^ In this example, "approaching" points are yellow, "visiting" points are green, and the departure point is "red".

---

# Station Algorithm V2

- Step 1: assign locations to stations
- Step 2: update station phase history
- Step 3: select most relevant station phase

^ Station algorithm version 2 has 3 steps.

---

# Step 1: assign locations to stations

- Add each location to `visitingLocations` or `approachingLocations` for the closest station on each railway
- If there is no station history, add `firstDepartureLocation` to the closest station in opposite travel direction
- If a station has `visitingLocations` or `approachingLocations`, set a `firstDepartureLocation`
- If a location is stopped between stations, add it to `orphanedLocations` for the railway

^ In step 1, we categorize a location into "visiting", "approaching", "firstDeparture", or "orphaned".
^ TODO: should this be a simple illustration instead of text?

---

# Step 2: update station phase history

`visitingLocations` | `approachingLocations` | `firstDepartureLocation` | -> Phase
-|-|-|-
[]|[]|nil|departure
[]|[...]|nil|approaching
[...]|-|non-nil|visiting
[...]|-|non-nil|visited

^ In step 2, we the location category history to calculate the phase for each station.

---

# Step 3: select most relevant station phase

- Find last station `S` in travel direction where `phase != nil`

Station Phase|Result
-|-
departure|Next: `S`+1
approaching|Approaching: `S`
visiting|Visiting: `S`
visited|Next: `S`+1

^ In step 3, we look through the phase history for all stations to determine the "focus" phase.

---

Station|Latest Phase
-|-
Tsurumi|Visited
Kawasaki|Visited

# Next: **Kamata**

^ For example, when the latest phase for Tsurumi and Kawasaki is "Visited", then the focus phase is "Next: Kamata"

---

Station|Latest Phase
-|-
Musashi-Kosugi|Visited
Motosumiyoshi|Approaching

# Approaching: **Motosumiyoshi**

^ For example, when the latest phase for Musashi-Kosugi is "Visited" and Motosumiyoshi is "Approaching", then the focus phase is "Approaching: Motosumiyoshi"

---

We did it!

^ Our algorithm works well. But 

---

But can we distinguish "visited" and "passed"?

^ But can we tell the difference between a visited station and a passed station?

---

Train is **stopped** within station bounds for more than 20 seconds => `visited`

```swift
let earliestStoppedLocation = visitingLocations.first(where: { $0.speed <= 1.0 })
let latestStoppedLocation = visitingLocations.reversed().first(where: { $0.speed <= 1.0 })
latestStoppedLocation.timestamp.timeIntervalSince(earliestStoppedLocation.timestamp) > 20.0
```

^ If the train is stopped within a station's bounds for more than 20 seconds then it is visited.

---

Train is **moving** within station bounds for more than 70 seconds => `visited`

```swift
let earliestVisitedLocation = stationLocationHistory.visitingLocations.first
firstDepartureLocation.timestamp.timeIntervalSince(earliestVisitedLocation.timestamp) > 70.0
```

^ If the train is moving within a station's bounds for more than 70 seconds then it is visited.
^ This case is for stations with bad GPS reception.

---

Else => `passed`

^ Otherwise we consider the station as passed.

---

We did it!

^ Our algorithm works well for these cases.

---

TODO: Full demo of SessionViewer

^ Now I'd like to finish the talk by demoing the SessionViewer macOS app I created.
^ I'll show a journey from Kannai station to Kawasaki station on the Keihin-Tohoku Line.
^ It takes some time for all Locations to be processed by the algorithm.
^ I can start playback to see the journey at 10x speed.
^ In the right sidebar, you can see the algorithm's results updating.
^ Keihin-Tohoku line has the highest score.
^ The direction is northbound.
^ The latest phase for each station is shown.
^ We can see the phase history too.
^ When I click on a station, I can see the Locations used to calculate its phase.
^ When I click on the last Location, we can see the full station history.

---

github.com/twocentstudios/train-tracker-talk

^ The apps I used to collect this data are open source.
^ Unfortunately, I cannot include the static railway data.
^ TODO: QR Code, screenshots of all apps

---

# Future Research

- Subway support
	- Custom ML Model for device velocity using accelerometer
	- Stairs counter to detect subway entrance
- Estimate exact train car from timetable
	- Show arrival times
	- Show next stop for express vs. local

^ The algorithm can still be improved.

---

# Full version

- Eki Live on the App Store

^ The full version of this app is on the App Store now.
^ It's called Eki Live.
^ The app starts up automatically in the background and shows the next station in the dynamic island.
^ TODO: QR Code

---

# Hire Me

- Freelance or full-time
- iOS generalist (not just train apps)
- twocentstudios.com

^ I'm available for freelance or full-time work.
^ I write regularly on my blog twocentstudios.
^ That's all for today.
^ TODO: QR Code

