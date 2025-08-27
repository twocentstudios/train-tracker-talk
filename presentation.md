

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

This talk is about trains but...

^ most of us don't write train apps.

---

You'll learn:

- Why you should build prototypes to understand the behavior system frameworks
- How to break down a big problem
- Some random API trivia you can apply to your current project

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

## Significant-change location service

- Uses cellular & Wi-Fi radios, not GPS
- Automatically relaunches app in background
- Device moves 500 meters
- Time between events is no shorter than 5 minutes

^ [Docs](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges())

---

# Prototype #1: Significant-change Location Data

^ Let's build a prototype that logs every significant-change location
^ TODO: screenshot of prototype

---

# User Timeline

^ TODO: illustration of timeline of user's activity zoomed out to full day

---

# User Timeline

^ TODO: illustration of timeline of user's activity zoomed in to train boarding

---

0. [x] How to detect the user has changed location
1. **How to detect a journey has started**
2. How to determine railway and direction
3. How to detect a journey has ended

---

# Start tracking or go back to sleep?

---

# Problems

- Is user moving?
- Car, train, bike, walking, jogging?
- Is user stopped at a station?
- Is the user in Japan?

^ TODO: Punch up the text on this slide

---

# Goal: minimize app time spent running

---

# Prototype #2: GPS Startup Time

^ TODO: screenshot of prototype
^ Collect 3 minutes of location data after significant location change

---

# Prototype #2
## Results

^ TODO: 
^ map of location data annotated with transport mode
^ use accuracy, speed
^ decide on 6 m/s, 21 km/h

---

1. [x] How to detect a journey has started
2. How to determine railway and direction
3. **How to detect a journey has ended**

---

Speed < 6 km/h
The user is walking

---

# How to detect the user is walking?

---

# Core Motion

---

# Prototype #3: Motion Activity

^ Screenshot of prototype

---

# User Timeline

^ TODO: illustration of timeline of end of journey where `walking` is triggered

---

1. [x] How to detect a journey has started
2. How to determine railway and direction
3. [x] **How to detect a journey has ended**

---

1. How to detect a journey has started
2. **How to determine railway and direction**
3. How to detect a journey has ended

---

# Let's write the tracking algorithm

---

# How can we write a data processing algorithm without data?

---

- [ ] **Live GPS data**
- [ ] Static railway data

---

# Prototype #4: GPS data collection

^ TODO: screenshots

---

- [x] Live GPS data
- [ ] **Static railway data**

---

# Railway data Tables

- Railways (JR Tokaido)
- Rail Directions (Northbound)
- Stations (Shinagawa)
- RailwayCoordinate (Points that make up a Railway)

---

# Illustrated Data

^ TODO: map showing a railway, rail direction, station, coordinate

---

- [x] Live GPS data
- [x] **Static railway data**

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
- Transfer from local to express mid-journey

^ TODO: lay out in grid

---

We need a way to iterate quickly on our algorithm

---

# Prototype #5: macOS viewer app

^ TODO: screenshot of just sidebar and map and locations

---

# Scoring system

- Higher scores are better
- Instantaneous score: calculated for each GPS coordinate
- Overall score: maintained over lifetime of session

---

# Railway proximity score

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