

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

# As a train passenger...

- I know how to get to my destination
- I don't need timetables
- I want to passively monitor my trip

---

# Problem

## While on the train...

- I can't see the announcement board
- I can't hear the loudspeaker
- I can't see out the window

^ TODO: images

---

## I don't need a full navigation app

^ It's annoying to open an app, choose my destination, choose my route

---

# Let's Write a Zero-Tap Train Tracking App

---

# Specifications

- Automatically start tracking when boarding a train
- Automatically determine railway and direction
- Automatically update a Live Activity
- Automatically stop when getting off a train

---

# Guiding Principles

- Preserve battery life
- Respect user privacy
- Convey accuracy of prediction

^ Natural limitations: GPS accuracy, car/train differentiation, underground, startup time

---

# Goal UX

^ TODO: video of live activity appearing in dynamic island
^ TODO: video of live activity updating
^ TODO: video of full tracking UI with live video

---

# 3 Algorithms

1. How to detect a journey has started
2. How to determine railway, direction, station
3. How to detect a journey has ended

---

1. **How to detect a journey has started**
2. How to determine railway and direction
3. How to detect a journey has ended

---

# [fit] The app can't run 24/7

---

# App Wake Up Strategies

- 24/7 Location Monitoring
- Geofencing
- Significant-change Location Service
- Location Push Notification Extension

---

# Journey Start Strategies

 | Battery Life | User Privacy | Accuracy | Simplicity
---|:---:|:---:|:---:|:---:
Location Monitoring|❌|❌|✅|✅
Significant-change|✅|✅|⚠️|✅
Geofencing|✅|✅|❌|⚠️
Location Push|❌|❌|✅|❌

^ [Location Push Service Extension](https://developer.apple.com/documentation/corelocation/creating-a-location-push-service-extension)
^ [Geofencing](https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions)

---

## Significant-change location service

- Uses cellular & Wi-Fi radios, not GPS
- Automatically relaunches app in background
- Device moves 500 meters
- One event every 5 minutes at most

^ [Docs](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges())

---

# Prototype #1: Significant-change Location Data

---

# Prototype #1
## Goals

Significant-change behavior...

- while walking
- on local train
- on express train
- in car
- on bike
- at home

---

# Prototype #1
## Code

^ TODO: code for setting up significant location monitoring in background and writing to SQLite

---

# Prototype #1
## Results

^ TODO: 
^ map of location data annotated with transport mode
^ summarize learnings in one or two bullets

---

# User Timeline

^ TODO: illustration of timeline of user's activity vs when the app is awakened and what it's doing

---

# Start tracking
# or
# Go back to sleep

---

# Problems

- Is user moving?
- Car, train, bike, walking?
- Is user stopped at a station?
- Is the user in Japan?

^ TODO: Punch up the text on this slide

---

# Goal: minimize app time spent running

---

# What's the most efficient strategy?

---

# How fast can the app detect train riding via GPS?

---

# Prototype #2: GPS Startup Time

^ Augment prototype 1 so that it collects 3 minutes of location data after waking up

---

# Prototype #2
## Goal

- Collect enough data to determine proper confidence ratio

---

# Prototype #2
## Code

^ TODO: code for start location monitoring in background, writing to SQLite, stopping after time interval

---

# Prototype #2
## Results

^ TODO: 
^ map of location data annotated with transport mode
^ use accuracy, speed, distance from railway line/station

---

# Can we augment GPS?

---

# Core Motion (Accelerometer)

---

# Prototype #3: Motion Activity

^ TODO: 
^ tab 1: show last live value with log
^ tab 2: show full history as log and graph

---

# Prototype #3
## Code

^ TODO: code for viewing live core motion and reading history

---

# Prototype #3
## Results

^ TODO: show app screens, explain data

---

# Provisional Tracking Flow

```
wake up from significant location change ->
check for automotive motion since last wakeup ->
(if not or indeterminate) start full location services ->
monitor until XX% confidence
```

^ TODO: visual flowchart

---

# App Flowchart

```
Waiting for Location Change -> 
Provisional Tracking -> 
Qualified Tracking
```

^ TODO: create visual flowchart

---

# Qualified Tracking

---

1. How to detect a journey has started
2. **How to determine railway and direction**
3. How to detect a journey has ended

---

# Let's write the tracking algorithm

---

# How can we write a data processing algorithm without data?

---

# Prototype #4: GPS data collection

^ TODO: start tracking automatically, create session, write location data to db, stop when user taps button

---

# Prototype #4
## Results

^ TODO: show session as tabular data inside app

---

# Railway data review

- ODPT
- Open Street Map
- Mini Tokyo 3D

^ Please check licenses

---

# Write custom importer

`json/tabular -> sqlite`

---

# Embed sqlite db in app binary

^ TODO: appx size

---

# Tables

- Railways (JR Tokaido)
- Rail Directions (Northbound)
- Stations (Shinagawa)
- RailwayCoordinate (Points that make up a Railway)

---

# Illustrated Data

^ TODO: map showing a railway, rail direction, station, coordinate

---

# Let's finally write the tracking algorithm

---

# Problems

- Parallel railways
- Above ground & Underground
- GPS dead zones
- Cars & Bikes
- Shared train car between railways
- Doubling back on the same Railway
- Underground transfers
- Long stops
- Front car vs. back car
- Emergency stops between stations

---

# Solution(?)

Use a scoring system

---

# Scoring system

- Higher scores are better
- Instantaneous score: calculated for each GPS coordinate
- Overall score: maintained over lifetime of session

---

# Instantaneous Railway score

- GPS coordinate distance and accuracy from closest railway coordinate
- Compare to railway coordinate due to:
	- Fastest detection when tracking starts while between stations
	- Tokaido vs. Keihin-Tohoku problem (TODO)
	- Toyoko-sen vs. Meguro-sen problem (TODO)
	
^ TODO: expand on this and show examples on map

---

# Instantaneous Rail Direction score

- Each scored railway gets a proposed Rail Direction
- Use dot product on 4 nearest stations
	- Musashi-Kosugi problem (TODO)
- Assume this doesn't change over a session

^ TODO: expand on this and show examples on map




```
>>>>>>>>>> TODO tomorrow
>>>>>>>>>> Finish main tracking algorithm outline
>>>>>>>>>> Prototype #5 macOS app    
>>>>>>>>>> Stopping algorithm outline
>>>>>>>>>> Live Activity push notification outline
```


---

# Future Research

- Subway support
	- Custom ML Model for device velocity using accelerometer
	- Stairway counter to detect subway entrance
- Estimate exact train car from timetable
	- Show arrival times
	- Show next stop for express vs. local

^ TODO: blog post about other company's subway ML model

---

# Full version

- Eki Live on the App Store
- Research Preview quality

^ TODO: QR Code

---

# Hire Me

- Freelance or full-time
- iOS generalist (not just train apps)

---

# Contact

- twocentstudios.com
- English blog

^ TODO: QR Code

---

# Thanks

Ask me questions at Q&A