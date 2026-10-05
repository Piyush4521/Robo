#include <Arduino.h>
#include <Wire.h>
#include "BoardProfile.h"
#include "JointConfig.h"
#include "PCA9685_Driver.h"
#include "SafetyController.h"
#include "MotionEngine.h"
#include "ProtocolParser.h"
#include "HardwareValidation.h"

// If on UNO or Nano, include SoftwareSerial for HC-05
#if (TARGET_BOARD != BOARD_TYPE_MEGA)
  #include <SoftwareSerial.h>
  SoftwareSerial btSerial(CURRENT_BOARD_PROFILE.btRxPin, CURRENT_BOARD_PROFILE.btTxPin);
  Stream& g_btStream = btSerial;
#else
  // On Arduino Mega 2560, use Hardware Serial1 (pins 19 RX, 18 TX)
  HardwareSerial& g_btStream = Serial1;
#endif

// Core subsystems
PCA9685_Driver      g_driver(PCA9685_I2C_ADDR);
SafetyController    g_safety(g_driver);
MotionEngine        g_motion(g_driver, g_safety);
ProtocolParser      g_parser(g_safety, g_motion, g_driver);
HardwareValidation  g_validator(g_driver, g_safety, g_motion);

void setup() {
    // 1. USB Debug Serial
    Serial.begin(CURRENT_BOARD_PROFILE.debugBaudRate);
    Serial.println();
    Serial.println(F("=========================================="));
    Serial.println(F("ROBOTIC ARM 6-DOF CONTROLLER FIRMWARE v1.0"));
    Serial.print(F("Target Board: "));
    Serial.println(CURRENT_BOARD_PROFILE.boardName);
    Serial.println(F("=========================================="));

    // 2. Bluetooth Serial
#if (TARGET_BOARD != BOARD_TYPE_MEGA)
    btSerial.begin(CURRENT_BOARD_PROFILE.btBaudRate);
#else
    Serial1.begin(CURRENT_BOARD_PROFILE.btBaudRate);
#endif
    Serial.print(F("HC-05 Serial initialized at baud: "));
    Serial.println(CURRENT_BOARD_PROFILE.btBaudRate);

    // 3. Initialize PCA9685 Driver
    Serial.print(F("Initializing PCA9685 at 0x"));
    Serial.print(PCA9685_I2C_ADDR, HEX);
    Serial.print(F(" (50 Hz)... "));

    if (g_driver.initialize(SERVO_FREQ_HZ)) {
        Serial.println(F("SUCCESS"));
    } else {
        Serial.println(F("FAILED! Check I2C wiring (SDA/SCL) and external 5V power."));
    }

    // 4. Initialize Safety & Motion Subsystems
    g_safety.begin();
    g_motion.begin();

    Serial.println(F("Safety controller initialized in DISCONNECTED state."));
    Serial.println(F("Ready for incoming HC-05 connection and HELLO handshake."));
    Serial.println(F("Type 'CHECKLIST' or 'TEST' on USB Serial for hardware validation."));
}

void loop() {
    uint32_t now = millis();

    // 1. Non-blocking update of Motion Engine and Safety Watchdog
    g_motion.update(now);
    g_safety.update(now);

    // 2. Process incoming data from Bluetooth (HC-05)
    while (g_btStream.available() > 0) {
        char c = (char)g_btStream.read();
        g_parser.processIncomingChar(c, g_btStream);
    }

    // 3. Process commands from USB Serial (for debugging and test harness)
    while (Serial.available() > 0) {
        char c = (char)Serial.read();

        // Pass directly to protocol parser with response back to USB Serial
        g_parser.processIncomingChar(c, Serial);
    }
}
