# Cardio Machine Gaming - Master Research
> Started: 2026-07-23 | Active Project

## Table of Contents
1. [The Connectivity Standard: FTMS](#1-the-connectivity-standard-ftms)
2. [What Machines Support (and What They Expose)](#2-what-machines-support)
3. [Existing Apps and Games (The Competition)](#3-existing-apps-and-games)
4. [Open-Source Libraries and Tools](#4-open-source-libraries-and-tools)
5. [DIY Hardware Hacks](#5-diy-hardware-hacks)
6. [VR and Game Engine Approaches](#6-vr-and-game-engine-approaches)
7. [Creative Game Concepts (Brainstorm)](#7-creative-game-concepts)
8. [Development Paths](#8-development-paths)
9. [Key Links and References](#9-key-links)

---

## 1. The Connectivity Standard: FTMS

### What is FTMS?
**Fitness Machine Service** - an open Bluetooth Low Energy (BLE) standard published by the Bluetooth SIG. It is the "USB-C of fitness equipment" - before FTMS, every brand had proprietary protocols.

### Key Technical Details
- **Service UUID:** `0x1826` (Fitness Machine)
- **Data Characteristic UUID:** `0x2ACD` - machine broadcasts metrics ~250ms intervals
- **Control Point UUID:** `0x2AD9` - app sends commands back to machine
- **Connection:** BLE 1:1 (one device at a time)

### What Machines Broadcast (Read)
| Metric | Treadmill | Bike | Rower | Elliptical |
|--------|-----------|------|-------|------------|
| Speed | Yes | Yes | Yes | Yes |
| Incline | Yes | - | - | Yes |
| Cadence (RPM) | Yes | Yes | Yes | Yes |
| Power (watts) | - | Yes | Yes | Yes |
| Distance | Yes | Yes | Yes | Yes |
| Heart Rate | Yes* | Yes* | Yes* | Yes* |
| Resistance | Rare | Yes | Yes | Yes |
| Calories / METs | Yes | Yes | Yes | Yes |
| Pace | Yes | - | Yes | - |

*HR only if paired to the machine's built-in HR receiver. Most apps pair a separate HRM via the standard Heart Rate BLE profile.

### What Apps Can Send Back (Control Point - Two-Way FTMS)
- Set target speed
- Set target incline
- Set speed AND incline simultaneously
- Start / Stop belt
- Pause / Resume
- Spin down (calibration)
- Target heart rate (auto-adjust speed)
- Target power / cadence (mostly bikes)
- Set resistance level (bikes)

### The Big Gotcha: Read-Only vs Two-Way FTMS
- **Read-Only FTMS:** Can read metrics but CANNOT control the machine. Very common.
- **Two-Way FTMS:** Full control. Required for auto-incline, auto-resistance, game integration.
- **NordicTrack/iFIT** machines have FTMS but LOCK the control point to their own app. No workaround.
- Many US-market treadmills are read-only or have locked control points.

### How to Check If a Machine Has FTMS
1. Check manual for "FTMS", "Bluetooth FTMS", or "Fitness Machine Service"
2. Use a free BLE scanner like `nRF Connect` - look for service UUID `0x1826`
3. Try connecting with Zwift or SummitRoom (free demo)
4. Post-2020 machines almost always support it
5. If it advertises compatibility with Zwift/Kinomap, it has FTMS

---

## 2. What Machines Support

### Treadmills (FTMS Support)
- **Full Two-Way:** Sole, Horizon, Bowflex, Echelon (some models), NoblePro, Matrix, LifeSpan, Spirit, 3G Cardio
- **Read-Only or Locked:** NordicTrack (iFIT locks control), Peloton Tread (limited), ProForm (iFIT locked)
- **Pre-2015:** Manual only - no BLE at all

### Exercise Bikes
- **Full Two-Way:** Wahoo KICKR, Tacx, Elite, Stages, Schwinn IC4/Bowflex C6, Keiser M3i, Echelon
- **Read-Only:** Peloton Bike (proprietary), some Domyos/Decathlon models
- **Note:** Bikes generally have BETTER FTMS implementation than treadmills

### Rowing Machines
- **Full Two-Way:** Concept2 (PM5 monitor - has its own protocol but also broadcasts FTMS-like data), WaterRower with SmartRow
- **FTMS Support:** Many newer rowers

### Ellipticals
- Mixed support. Newer models from Sole, Bowflex, Matrix support FTMS.

---

## 3. Existing Apps and Games (The Competition)

### Virtual World / Simulator Apps

| App | Type | Platforms | Price | FTMS Control | Notable Features |
|-----|------|-----------|-------|--------------|------------------|
| **Zwift** | Virtual 3D world | iOS/Android/Mac/Windows/AppleTV | $14.99/mo | Yes | Massively multiplayer, races, gamified XP/levels, cycling+running |
| **SummitRoom** | Virtual route running | Web (browser) | Free tier | Two-way for incline | No install, browser-based, auto-incline from route profile |
| **Rouvy** | Real video + AR cyclists | iOS/Android/Mac/Windows/AppleTV | $14.99/mo | Yes | Real geolocated video routes, augmented reality riders |
| **Kinomap** | Real geolocated video | iOS/Android/Web | ~$9.99/mo | Yes (auto-resistance) | Largest video library, cycling+running+rowing |
| **FulGaz** | Real video routes | iOS/Android/Mac/AppleTV | $12.99/mo | Yes | High-quality 4K real-world footage |
| **BitGym** | Immersive scenery | iOS/Android | $7.99/mo | Read-only only | First-person trail videos, simpler/no control |

### VR Fitness Games

| App | Platform | FTMS | Concept |
|-----|----------|------|---------|
| **Octonic VR** | Meta Quest | Yes - 40+ brands | VR running/cycling worlds, motion engine syncs treadmill speed, passthrough safety |
| **Pedal Rebel VR** | Quest/PCVR (indie) | Unknown | Cyberpunk street racing on exercise bike, Unity-based |
| **Adrienalin** | PC (Unreal Engine 5) | FTMS planned | Live fitness in UE5, FTMS cadence/power/resistance → game world |
| **FitOSC** | PC + VRChat | Yes | Treadmill → VRChat avatar movement via OSC, open source |
| **Supernatural** | Meta Quest | No (motion-only) | Rhythm-based, no machine connection, body-tracking only |

### Training/Data Apps
- **Fitscope** - FTMS-connected streaming classes with live metrics overlay
- **Track My Indoor Workout** - Open source, records FTMS data, exports to Strava/SUUNTO/TP
- **ErgData** - Concept2 official app (rowing)
- **COZWEAT** - "Zwift for rowing" (Concept2)

### Bridge/Adapter Apps
- **QZ Fitness (qdomyos-zwift)** - THE open-source bridge. Connects locked/proprietary machines to Zwift/Peloton/Strava. iOS/Android/Raspberry Pi/Windows/Mac. Supports NordicTrack, Echelon, ProForm, Bowflex, Schwinn, Keiser, etc. Translates proprietary protocols → FTMS.
- **QZ Companion NordicTrack** - Side-loaded app for NordicTrack treadmills that adds auto-incline and speed control.

---

## 4. Open-Source Libraries and Tools

### Libraries for Building Your Own

| Name | Language/Platform | What It Does |
|------|-------------------|--------------|
| **flutter_ftms** | Flutter (Dart) | FTMS BLE connectivity for Flutter apps. Scan, connect, read data, control point. pub.dev package. |
| **qdomyos-zwift** | C++/Qt | Full open-source bridge app. Source on GitHub (cagnulein). Reference implementation. |
| **Track My Indoor Workout** | ? | Open-source workout recorder. FTMS → FIT/TCX/CSV/JSON → Strava/etc. |
| **RowMate** | Android (Kotlin) | Open-source rowing app for FTMS rowers. Codeberg. |

### For Unity Game Engine
- **BleWinrtDll** (GitHub: adabru/BleWinrtDll) - BLE connector for Unity 3D on Windows. Used to connect exercise equipment.
- Unity forum threads exist on connecting Wahoo KICKR via BLE. Desktop BLE is the main challenge - most BLE libraries are mobile-only.

### For Python
- **bleak** - Cross-platform BLE library for Python. Can connect to FTMS devices, read characteristics.
- **pycycling** - Python library specifically for cycling power meters and trainers (ANT+ and BLE).

### Data Formats
- Output: FIT, TCX, CSV, JSON
- Platforms to integrate: Strava API, Garmin Connect, TrainingPeaks, SUUNTO

---

## 5. DIY Hardware Hacks

### ESPHome Treadmill FTMS
- **Platform:** ESP32-S3 + ESPHome firmware
- **What it does:** Complete treadmill computer replacement. Implements FTMS protocol. Native Zwift route-grade incline. Home Assistant integration. Nextion touch UI. Advanced training modes.
- **Connection:** UART to treadmill motor controller, BLE FTMS broadcast
- **Status:** Active open-source project (osrtos.com, GitHub)

### Smart Treadmill Adapter FTMS
- **Repo:** benb0jangles/Smart-Treadmill-Adapter-FTMS-Bluetooth
- **What it does:** BLE broadcasting via FTMS for older treadmills. Peloton app compatible. iOS/Android support. Live metrics during workout + post-workout summary.

### USB-HID Treadmill Hack
- Intercept USB HID signals from treadmill consoles to read or inject data

### WalkingPad
- Open-source control for WalkingPad treadmills

### General Approach for Older Machines
- **Raspberry Pi** as BLE FTMS bridge
- Read console data via UART/USB/sensor tap
- Broadcast as FTMS over BLE
- QZ Fitness already does this in software for many brands

---

## 6. VR and Game Engine Approaches

### The VR Opportunity
VR + cardio machine is an UNDERSERVED market:
- Octonic VR is the only polished commercial option on Quest
- Pedal Rebel VR is a solo indie dev project (proof it's doable)
- Adrienalin is pre-release (UE5)
- Nothing in the "actual game" space - everything is "virtual workout"

### Game Engines That Can Work
| Engine | BLE Support | Best For |
|--------|-------------|----------|
| **Unity** | BleWinrtDll (Windows), built-in BLE (mobile) | Cross-platform, largest community, mobile+desktop |
| **Unreal Engine 5** | Custom plugins, C++ BLE | High-end graphics, PC/console quality |
| **Godot** | GDNative/GDExtension for BLE | Open-source, lightweight |
| **Web (Three.js/Babylon.js)** | Web Bluetooth API | No install, browser-based, lowest friction |

### Key Technical Challenges
1. **Desktop BLE is harder than mobile BLE** - Most BLE libraries target iOS/Android. On desktop (Windows/Mac), BLE APIs are more limited.
2. **FTMS Control Point is locked on many machines** - Game needs read-only fallback mode
3. **Safety:** Auto-controlling a treadmill's speed is dangerous. Need dead-man switch, quick stop, gradual changes.
4. **Motion sickness in VR:** Running in VR while physically running on a treadmill is less nausea-inducing than standing still in VR while virtual-moving. The physical motion matches.

---

## 7. Creative Game Concepts (Brainstorm)

### A. Racing Games
- **Concept:** Speed = your actual treadmill speed. Compete against others in real-time.
- **Twist:** Drafting mechanics, power-ups collected by changing speed/incline
- **Reference:** Zwift already does this for cycling. Nobody has done it well for running.

### B. Endless Runner / Temple Run Style
- **Concept:** Side-scrolling or third-person runner. Speed controlled by treadmill speed. Jump/slide by incline changes.
- **Twist:** Procedurally generated terrain that matches incline changes
- **Platform:** Mobile phone game connected via BLE FTMS

### C. RPG / Adventure
- **Concept:** Your treadmill distance = character movement in an RPG world. Walking/running/sprinting mapped to character states.
- **Twist:** Towns, quests, loot tied to workout milestones. "You ran 5K - you found a rare sword!"
- **Reference:** "Ring Fit Adventure" (Nintendo Switch) but for actual cardio machines

### D. Zombie Chase / Survival
- **Concept:** Zombies chase you. Your actual speed determines if you escape. Sprint = sprint in game.
- **Twist:** Incline = climbing obstacles. Stop = you get caught.
- **Reference:** "Zombies, Run!" app but with actual speed-tracking from the machine

### E. Flight / Wingsuit Sim
- **Concept:** Treadmill speed = airspeed. Incline = pitch/altitude. Steer with phone tilt.
- **Twist:** Fly through canyons, collect rings, race ghosts

### F. Rowing = Boat/Ship Game
- **Concept:** Rower stroke rate = oar speed. Power = boat speed. Compete in regattas or pirate ship battles.
- **Twist:** Crew management RPG, naval combat, treasure hunting

### G. Multiplayer Social
- **Concept:** Virtual gym. See friends' avatars running/biking next to you. Chat, race, do group workouts.
- **Twist:** Virtual classes with real-time metrics. Coach can see everyone's actual output.

### H. Rhythm Game
- **Concept:** Beat Saber / Guitar Hero but your steps/cadence must match the beat. Speed changes with song tempo.
- **Twist:** Incline = note lanes. Resistance = difficulty.

### I. Exploration / Open World
- **Concept:** Google Earth / real-world map integration. Run actual city streets. See real street view as you go.
- **Twist:** Collectibles placed on real-world map coordinates. "Run the Boston Marathon route."

### J. Idle/Progression Hybrid
- **Concept:** Your workout generates resources for a base-building or idle game. The game progresses while you work out, but also has a light management layer you check between workouts.
- **Twist:** Workout consistency = resource multipliers. "Don't break the streak."

---

## 8. Development Paths

### Path A: Mobile Game + FTMS (Lowest Barrier)
- **Stack:** Flutter + flutter_ftms or React Native + custom BLE module
- **Pros:** Direct BLE access on mobile, large audience, app store distribution
- **Cons:** Small screen, less immersive
- **Game type:** Endless runner, RPG, rhythm game

### Path B: Web Game + Web Bluetooth API (No Install)
- **Stack:** Three.js/Babylon.js + Web Bluetooth API
- **Pros:** No install, works on any device, instant sharing
- **Cons:** Web Bluetooth only works on Chrome/Edge (not Safari/Firefox), limited FTMS library support
- **Game type:** Any 3D web game

### Path C: VR Game (Most Immersive)
- **Stack:** Unity + BleWinrtDll or Meta Quest native BLE
- **Pros:** Most immersive, highest "wow factor," fitness+VR is a growing niche
- **Cons:** Smaller audience, development complexity, motion safety concerns
- **Game type:** Racing, flight, adventure

### Path D: Desktop Game + FTMS Bridge (Most Powerful)
- **Stack:** Unreal Engine 5 or Unity + QZ Fitness bridge or custom BLE plugin
- **Pros:** Best graphics, can use existing game engines fully, PC power
- **Cons:** Requires bridge app for BLE on desktop, setup friction
- **Game type:** Any AAA-quality concept

### Path E: Hardware Mod (For Old Machines)
- **Stack:** ESP32 + FTMS firmware
- **Pros:** Works with ANY treadmill/bike, full control, sellable product
- **Cons:** Hardware manufacturing, support, liability
- **Game type:** N/A - this is the connectivity layer

---

## 9. Key Links and References

### Standards and Specs
- Bluetooth FTMS Spec: https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0/
- FTMS ICS PDF: https://files.bluetooth.com/wp-content/uploads/dlm_uploads/2024/10/FTMS.ICS.p5.pdf

### Technical Articles
- SummitRoom FTMS Explained: https://summitroom.app/blog/ftms-explained-bluetooth-treadmill-protocol
- Fitscope FTMS Integration Guide: https://www.fitscope.com/blog/bluetooth-ftms-integration-for-fitness-apps
- Medium - Take Control of Fitness Machines: https://medium.com/decathlondigital/take-control-of-your-fitness-machines-6588439aeeda
- 3G Cardio - FTMS Control Reality: https://www.3gcardio.com/can-ftms-bluetooth-actually-control-your-treadmill-speed-app-limitations-how-qz-fitness-changes-everything/

### Open Source Repos
- GitHub FTMS Topic: https://github.com/topics/ftms
- QZ Fitness (qdomyos-zwift): https://github.com/cagnulein/qdomyos-zwift
- QZ NordicTrack Companion: https://github.com/cagnulein/QZCompanionNordictrackTreadmill
- flutter_ftms: https://pub.dev/packages/flutter_ftms
- Track My Indoor Workout: https://trackmyindoorworkout.github.io/
- RowMate: https://codeberg.org/minardil/RowMate
- Smart Treadmill Adapter: https://github.com/benb0jangles/Smart-Treadmill-Adapter-FTMS-Bluetooth
- FitOSC (VRChat + treadmill): https://github.com/Duinrahaic/FitOSC
- ESPHome Treadmill FTMS: https://osrtos.com/projects/esphome-treadmill-ftms/
- Top Treadmill Open-Source: https://www.libhunt.com/topic/treadmill

### VR / Game Projects
- Octonic VR: https://octonicvr.com/
- Adrienalin (UE5): https://www.adrienalin.com/
- Pedal Rebel VR: YouTube - "My VR cyberpunk street racing exercise bike game"

### Existing Apps (Competition)
- Zwift: https://www.zwift.com/
- SummitRoom: https://summitroom.app/
- Kinomap: https://www.kinomap.com/
- Rouvy: https://rouvy.com/
- QZ Fitness: https://www.qzfitness.com/

### QZ Fitness Detail
- THE open-source bridge for locked machines
- Runs on: iOS, Android, Windows, Mac, Raspberry Pi
- Connects proprietary protocols → FTMS → Zwift/Peloton/Strava
- Compatible with: Domyos, Echelon, Proform, Bowflex, Schwinn, Keiser, NordicTrack, Flywheel, Toorx
- QZ Companion app adds auto-incline to NordicTrack treadmills
- Guide: https://yourexercisebike.com/qz-application/
- 5KRunner review: https://the5krunner.com/2026/05/07/qz-qdomyos-zwift-app/

---

## Quick-Start Research To-Do
- [ ] Check what FTMS data a real treadmill actually broadcasts (use nRF Connect)
- [ ] Prototype BLE FTMS connection from Python (bleak) or Flutter (flutter_ftms)
- [ ] Test read-only vs two-way on available machines
- [ ] Evaluate Web Bluetooth API viability for web game approach
- [ ] Study QZ Fitness source code for protocol translation patterns
- [ ] Test Octonic VR for UX reference
- [ ] Prototype simple Unity game with BleWinrtDll
