# 🦾 6-DOF Robotic Arm Professional Controller & Firmware

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Arduino](https://img.shields.io/badge/Arduino-C%2B%2B-00979D?logo=arduino&logoColor=white)](https://www.arduino.cc/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An industrial-grade, end-to-end control suite for a **6-Degree-of-Freedom (6-DOF) Robotic Arm**. The project includes a high-performance **Flutter Android Controller Application** with real-time 3D kinematic visualization, paired with **Arduino Firmware** that orchestrates 6 servo motors through a PCA9685 16-channel 12-bit PWM driver over Bluetooth Classic (HC-05).

---

## 📌 Table of Contents

- [System Architecture](#-system-architecture)
- [Repository Structure](#-repository-structure)
- [Key Features](#-key-features)
- [Hardware Wiring & Pinout](#-hardware-wiring--pinout)
- [Communication Protocol](#-communication-protocol)
- [Installation & Setup](#-installation--setup)
  - [Prerequisites](#prerequisites)
  - [1. Clone Repository](#1-clone-the-repository)
  - [2. Flash Arduino Firmware](#2-flash-arduino-firmware)
  - [3. Run or Build Flutter Mobile App](#3-run-or-build-flutter-mobile-app)
- [Git Commands Reference](#-git-commands-reference)

---

## 🏗️ System Architecture

```
┌──────────────────────────────────────────┐
│          Android Mobile Device           │
│   Flutter App (UI & 3D Kinematics)       │
│   Native Kotlin Bluetooth SPP Bridge     │
└────────────────────┬─────────────────────┘
                     │  RFCOMM / SPP (9600 Baud)
                     │  Line-Delimited ASCII Protocol
                     ▼
┌──────────────────────────────────────────┐
│          HC-05 Bluetooth Module          │
└────────────────────┬─────────────────────┘
                     │  UART (RX / TX)
                     ▼
┌──────────────────────────────────────────┐
│        Arduino (Uno / Nano / Mega)       │
│   - Protocol Parser (Zero-Heap)          │
│   - Safety Controller & Watchdog (1000ms)│
│   - Motion Engine (S-Curve & Synchronous)│
└────────────────────┬─────────────────────┘
                     │  I2C (SDA / SCL - Address 0x40)
                     ▼
┌──────────────────────────────────────────┐
│      PCA9685 16-Channel 12-bit PWM       │
│       External 5V/6V High-Current PSU    │
└───────┬──────┬──────┬──────┬──────┬──────┘
        │      │      │      │      │
       CH0    CH1    CH2    CH3    CH4    CH5
      [Base] [Shld] [Elbw] [W-Pt] [W-Rl] [Grip]
```

---

## 📂 Repository Structure

```tree
Robo/
├── .gitignore                     # Comprehensive git ignore rules (builds, caches, local SDKs)
├── README.md                      # Primary project documentation
├── Robotic_Arm_Flutter_App_Master_Plan.pdf # Hardware & Software Master Architecture
├── arm_left_full.png              # Reference kinematics diagram (left view)
├── arm_right_full.png             # Reference kinematics diagram (right view)
├── robot_arm_clean.png            # Visual reference of assembled 6-DOF arm
├── firmware/                      # Microcontroller Firmware
│   └── arduino/
│       ├── RobotArm6DOF.ino       # Main Arduino sketch & loop orchestration
│       ├── BoardProfile.h         # Pin mappings & board profiles (Uno, Nano, Mega)
│       ├── JointConfig.h          # Joint pulse limits (μs), angles & speed boundaries
│       ├── PCA9685_Driver.h/.cpp  # Direct I2C driver for 16-ch 12-bit servo controller
│       ├── MotionEngine.h/.cpp    # Non-blocking trajectory generation & multi-joint sync
│       ├── SafetyController.h/.cpp# E-STOP latching, communication watchdog & boundary checks
│       ├── ProtocolParser.h/.cpp  # Zero-heap deterministic ASCII command parser
│       ├── HardwareValidation.h/.cpp # Self-test diagnostic test harness
│       └── protocol.md            # Complete ASCII protocol specification
└── robot_arm_app/                 # Flutter Android Mobile Application
    ├── pubspec.yaml               # Flutter dependencies & app metadata
    ├── android/                   # Native Android host project
    │   └── app/src/main/kotlin/.../MainActivity.kt # Custom RFCOMM Bluetooth SPP implementation
    ├── assets/                    # App images, branding, and icons
    └── lib/
        ├── main.dart              # Application bootstrap & 4-tab navigation shell
        ├── bluetooth/
        │   ├── bluetooth_connection.dart # Connection interface
        │   ├── bluetooth_manager.dart    # State machine & connection recovery
        │   └── command_protocol.dart     # Protocol encoder/decoder & packet builders
        ├── controllers/
        │   └── robot_controller.dart     # Central application state & command dispatch
        ├── core/
        │   ├── constants/                # Colors, dimensions, and limits
        │   ├── safety/                   # Client-side kinematics boundary validator
        │   └── theme/                    # Industrial dark/light theme
        ├── models/
        │   ├── joint.dart                # Joint models & calibration constraints
        │   ├── robot_pose.dart           # 6-angle pose data structures
        │   ├── robot_state.dart          # Connection, motion, and fault states
        │   └── sequence.dart             # Pick-and-place automated sequences
        ├── screens/
        │   ├── home/                     # Status dashboard, quick actions, 3D viewport
        │   ├── control/                  # Dual touch joysticks & fine jog buttons
        │   ├── pose/                     # Individual joint angle sliders & staging
        │   ├── saved/                    # Preset pose manager & sequence runner
        │   ├── settings/                 # Device scanner, baud rates & diagnostic logs
        │   └── splash/                   # Animated startup screen
        ├── services/
        │   └── preset_service.dart       # Local persistence for poses & sequences
        └── widgets/
            ├── angle_row.dart            # Degree precision control sliders
            ├── emergency_stop.dart       # High-visibility safety latch E-STOP
            ├── joystick.dart             # Custom 2-axis virtual joystick
            ├── robot_3d_renderer.dart    # Live vector/3D visual projection of the arm
            └── robot_status.dart         # Telemetry bar (link quality, state, angles)
```

---

## ⚡ Key Features

### 📱 Flutter Mobile Application
1. **Interactive Real-Time 3D Kinematics**: Visualizes arm orientation dynamically as joint angles adjust.
2. **Dual Control Modes**:
   - **Virtual Joysticks & Jog**: Analog touch control for fluid manual positioning (`J+`, `J-`, `J0`).
   - **Precision Angle Sliders**: Degree-accurate sliders for Base, Shoulder, Elbow, Lower Arm, Wrist, and Gripper.
3. **Hardware Safety Guard**:
   - Software boundary clamps prevent servo binding and mechanical collision.
   - Dedicated **Emergency Stop (E-STOP)** button with immediate motion halt.
4. **Native Android Bluetooth SPP**: Direct Kotlin `MethodChannel`/`EventChannel` RFCOMM implementation supporting Android 12+ (API 31+) runtime permissions without buggy 3rd-party plugins.
5. **Pose Library & Sequence Automation**: Save custom positions, configure delay timings, and automate multi-step pick-and-place routines.

### 🤖 Arduino Firmware
1. **Zero-Heap Command Parser**: Safe, non-allocating circular buffer ASCII parser that prevents memory fragmentation.
2. **Synchronized S-Curve Motion Engine**: Smooth acceleration and deceleration profiles prevent jerky movement and reduce servo gear wear.
3. **Safety Watchdog**: Auto-halts arm motion if communication is lost for more than 1000ms.
4. **Multi-Board Support**: Pre-configured profiles for **Arduino Uno**, **Arduino Nano**, and **Arduino Mega 2560**.

---

## 🔌 Hardware Wiring & Pinout

### 1. Arduino to HC-05 Bluetooth Module
| HC-05 Pin | Arduino Uno / Nano | Arduino Mega 2560 | Notes |
|:---|:---|:---|:---|
| **VCC** | 5V | 5V | Power input |
| **GND** | GND | GND | Common ground |
| **TXD** | Pin 10 (Soft RX) | Pin 19 (RX1) | Arduino receives from HC-05 |
| **RXD** | Pin 11 (Soft TX)* | Pin 18 (TX1)* | *Use 1kΩ / 2kΩ resistor divider (5V -> 3.3V) |

### 2. Arduino to PCA9685 Servo Driver
| PCA9685 Pin | Arduino Uno / Nano | Arduino Mega 2560 | Notes |
|:---|:---|:---|:---|
| **VCC** | 5V | 5V | Logic power |
| **GND** | GND | GND | Common ground |
| **SDA** | A4 | Pin 20 (SDA) | I2C Data line |
| **SCL** | A5 | Pin 21 (SCL) | I2C Clock line |
| **V+ (Screw Terminal)** | External 5V–6V (≥5A) | External 5V–6V (≥5A) | **DO NOT** power servos from Arduino 5V! |

### 3. PCA9685 Output Channels to 6 Servos
| Channel | Joint Name | Servo Model | Motion Range | Default Home |
|:---:|:---|:---|:---:|:---:|
| **CH0** | Joint 1: Base | MG996R | 0° – 180° | 90° |
| **CH1** | Joint 2: Shoulder | MG996R | 15° – 165° | 90° |
| **CH2** | Joint 3: Elbow | MG996R | 10° – 170° | 90° |
| **CH3** | Joint 4: Lower Arm / Pitch | MG996R / MG90S | 0° – 180° | 90° |
| **CH4** | Joint 5: Wrist Roll | MG90S / SG90 | 0° – 180° | 90° |
| **CH5** | Joint 6: Gripper | MG90S / SG90 | 10° (Open) – 75° (Clamped) | 20° |

---

## 📡 Communication Protocol

Communication occurs over Bluetooth Classic SPP at **9600 Baud** with newline-terminated (`\n`) ASCII strings.

### Handshake Sequence
```
Flutter App                      Arduino
    │                               │
    ├─────── "HELLO\n" ────────────>│  (Verifies link)
    │<────── "ROBOT_6DOF_READY v1\n"┤
    │                               │
    ├─────── "STATUS?\n" ──────────>│  (Requests state)
    │<────── "STATE:WAIT_ACK,..."───┤
    │                               │
    ├─────── "READY_ACK\n" ─────────>│  (Confirms active session)
    │<────── "OK\n" ────────────────┤  (Controls unlocked)
```

### Core Commands Reference
- `POSE:<b,s,e,l,w,g>`: Stages target angles in degrees (e.g. `POSE:90,75,110,90,85,28`).
- `MOVE`: Triggers coordinated S-curve motion toward staged pose.
- `STOP`: Halts active motion immediately and holds current angles.
- `ESTOP`: Emergency stop; immediately shuts off servo PWM and latches safety state.
- `RESET_ESTOP`: Clears emergency state after fault inspection.
- `HOME`: Moves all joints to calibrated rest/home positions.
- `J+:<id>` / `J-:<id>`: Continuous manual jogging while button is pressed.
- `J0:<id>`: Stop manual jog when button/joystick is released.
- `SPD:<1|2|3>`: Set speed profile (1 = Slow, 2 = Normal, 3 = Fast).

---

## 🚀 Installation & Setup

### Prerequisites
- **Git** installed on your system.
- **Flutter SDK** (`>= 3.12.0` / Dart SDK `>= 3.0.0`).
- **Android Studio** with Android SDK Command-line Tools and Platform Tools (API 31+).
- **Arduino IDE** (`>= 2.x`) or `arduino-cli`.
- USB Cable for Arduino and Android device (or Bluetooth-capable Android phone).

---

### 1. Clone the Repository

```bash
git clone https://github.com/Piyush4521/Robo.git
cd Robo
```

---

### 2. Flash Arduino Firmware

1. Connect your Arduino board to your computer via USB.
2. Launch **Arduino IDE** and open `firmware/arduino/RobotArm6DOF.ino`.
3. In `firmware/arduino/BoardProfile.h`, verify that your board target is set:
   ```cpp
   #define TARGET_BOARD BOARD_TYPE_UNO    // or BOARD_TYPE_NANO, BOARD_TYPE_MEGA
   ```
4. Select your Board and COM Port in **Tools > Board** and **Tools > Port**.
5. Click **Upload** (Ctrl + U).
6. Open **Serial Monitor** at **115200 baud** to verify initial calibration and initialization logs.

---

### 3. Run or Build Flutter Mobile App

Navigate to the Flutter application directory:

```bash
cd robot_arm_app
```

#### Install Dependencies:
```bash
flutter pub get
```

#### Run on Connected Android Device (Debug Mode):
```bash
flutter run
```

#### Build Release APK:
```bash
flutter build apk --release
```
The compiled production APK will be generated at:
```
robot_arm_app/build/app/outputs/flutter-apk/app-release.apk
```

---

## 🛠️ Git Commands Reference

### Initialize and Push to GitHub
```bash
# Initialize local Git repository
git init

# Add all project source files (excluding builds & caches via .gitignore)
git add .

# Commit files
git commit -m "feat: complete 6-DOF robotic arm firmware and Flutter controller app"

# Set default branch to main
git branch -M main

# Link remote GitHub repository
git remote add origin https://github.com/Piyush4521/Robo.git

# Push whole codebase to GitHub
git push -u origin main
```

### Pulling Updates Later
```bash
git pull origin main
```

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
