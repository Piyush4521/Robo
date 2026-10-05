# 6-DOF Robotic Arm ASCII Communication Protocol Specification

## 1. Overview
The communication protocol between the Flutter Android Application and the Arduino controller over HC-05 Bluetooth Classic SPP is a line-delimited (`\n` terminated), ASCII-based, deterministic, zero-heap-allocation protocol.

## 2. Connection & Handshake State Machine
Bluetooth RFCOMM socket connection alone **does not** imply the robot is ready. A 3-step handshake is strictly required:

```
Flutter (App)                Arduino Firmware
   │                               │
   ├────────── HELLO ─────────────>│  (State: HANDSHAKE_WAIT_STATUS)
   │<─── ROBOT_6DOF_READY v1 ──────┤
   │                               │
   ├────────── STATUS? ───────────>│  (State: HANDSHAKE_WAIT_ACK)
   │<─── STATE:WAIT_ACK,... ───────┤
   │                               │
   ├────────── READY_ACK ─────────>│  (State: READY)
   │<─────────── OK ───────────────┤
   │                               │
```

Only after receiving `OK`, the App marks `robotReady = true` and unlocks motion controls.

## 3. Command Set
Every command is sent followed by newline (`\n` or `\r\n`).

| Command | Arguments | Example | Description |
|---|---|---|---|
| `HELLO` | None | `HELLO` | Step 1 of handshake. Initiates session. |
| `STATUS?` | None | `STATUS?` | Step 2 of handshake or periodic telemetry query. |
| `READY_ACK` | None | `READY_ACK` | Step 3 of handshake. Confirms app is ready. |
| `PING` | None | `PING` | Link health check. Arduino replies `PONG`. |
| `SEL:<id>` | `0..5` | `SEL:0` | Selects active joint for fine control mode (0: Base, 1: Shoulder, 2: Elbow, 3: Lower Arm, 4: Wrist, 5: Gripper). |
| `SPD:<spd>` | `1\|2\|3` | `SPD:2` | Sets speed profile: `1` = Slow, `2` = Normal, `3` = Fast. |
| `J+:<id>` | `0..5` (or omit) | `J+:1` | Momentary jog positive direction while held. |
| `J-:<id>` | `0..5` (or omit) | `J-:1` | Momentary jog negative direction while held. |
| `J0:<id>` | `0..5` (or omit) | `J0:1` | Cease manual jog immediately when released / joystick returns to neutral. |
| `POSE:<b,s,e,l,w,g>` | 6 floats | `POSE:90,75,110,90,85,28` | Pre-stages 6 target angles in degrees. |
| `MOVE` | None | `MOVE` | Initiates coordinated S-curve motion towards staged target pose. |
| `STOP` | None | `STOP` | Immediately halts active motion and holds commanded pose. |
| `ESTOP` | None | `ESTOP` | Emergency stop: halts motion, turns off PWM output, latches ESTOP state. |
| `RESET_ESTOP` | None | `RESET_ESTOP` | Explicit recovery clearance from ESTOP. |
| `HOME` | None | `HOME` | Smooth coordinated movement to pre-configured safe mechanical home. |
| `CALIB?` | None | `CALIB?` | Returns full diagnostic calibration table. |

## 4. Response Codes
- `ROBOT_6DOF_READY v1`: Response to initial `HELLO`.
- `STATE:<state>,MOTION:<motion>,SPD:<spd>,ANGLES:<b,s,e,l,w,g>`: Current state report.
  - State: `DISCONNECTED`, `READY`, `MOVING`, `STOPPED`, `ESTOP`.
  - Motion: `IDLE`, `MANUAL`, `MOVING_TO_TARGET`, `HOMING`.
  - Angles: Open-loop commanded angles (degrees, 1 decimal place).
- `OK`: Acknowledgment for `READY_ACK`.
- `ACK:<command>`: Command accepted and started.
- `ERR:NOT_READY`: Attempted motion before completing handshake.
- `ERR:LIMIT`: Target exceeds safe calibrated software boundaries.
- `ERR:ESTOP`: Motion rejected because ESTOP is latched.
- `ERR:TIMEOUT`: Communication timeout watchdog halted motion.
- `ERR:INVALID_JOINT`: Joint ID out of 0..5 range.
- `ERR:INVALID_SPEED`: Speed value out of 1..3 range.
- `ERR:INVALID_COMMAND`: Command unrecognized.
