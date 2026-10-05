#ifndef JOINT_CONFIG_H
#define JOINT_CONFIG_H

#include <Arduino.h>

#define NUM_JOINTS 6

// Joint IDs
#define JOINT_BASE      0
#define JOINT_SHOULDER  1
#define JOINT_ELBOW     2
#define JOINT_LOWER_ARM 3
#define JOINT_WRIST     4
#define JOINT_GRIPPER   5

// Servo Driver Configuration
#define PCA9685_I2C_ADDR   0x40
#define SERVO_FREQ_HZ      50

// Pulse lengths (in microseconds) for 50Hz PWM
#define MG995_MIN_PULSE_US   500
#define MG995_MAX_PULSE_US   2500
#define MG996R_MIN_PULSE_US  500
#define MG996R_MAX_PULSE_US  2500
#define SG90_MIN_PULSE_US    550
#define SG90_MAX_PULSE_US    2450

struct JointCalibration {
    uint8_t jointId;
    const char* name;
    uint8_t channel;        // PCA9685 channel (0-5)
    const char* servoType;
    int16_t safeMin;        // Safe minimum angle (degrees)
    int16_t safeMax;        // Safe maximum angle (degrees)
    int16_t safeHome;       // Calibrated mechanical home position (degrees)
    int16_t offset;         // Offset in degrees
    uint16_t minPulseUs;    // Min pulse width in microseconds
    uint16_t maxPulseUs;    // Max pulse width in microseconds
    float commandedAngle;   // Last commanded angle (OPEN-LOOP, NOT SENSOR MEASURED)
    float targetAngle;      // Active target angle
};

// Initial default calibration table based on physical arm specs
// Note: Hardware does not have position encoders. 'commandedAngle' is strictly
// the last commanded/calibrated value.
static JointCalibration g_joints[NUM_JOINTS] = {
    { JOINT_BASE,      "Base",      0, "MG995",   0, 180,  90, 0, MG995_MIN_PULSE_US,  MG995_MAX_PULSE_US,  90.0f, 90.0f },
    { JOINT_SHOULDER,  "Shoulder",  1, "MG996R", 15, 165,  75, 0, MG996R_MIN_PULSE_US, MG996R_MAX_PULSE_US, 75.0f, 75.0f },
    { JOINT_ELBOW,     "Elbow",     2, "MG996R", 20, 160, 110, 0, MG996R_MIN_PULSE_US, MG996R_MAX_PULSE_US,110.0f, 110.0f },
    { JOINT_LOWER_ARM, "Lower Arm", 3, "SG90",   10, 170,  90, 0, SG90_MIN_PULSE_US,   SG90_MAX_PULSE_US,   90.0f, 90.0f },
    { JOINT_WRIST,     "Wrist",     4, "SG90",    0, 180,  85, 0, SG90_MIN_PULSE_US,   SG90_MAX_PULSE_US,   85.0f, 85.0f },
    { JOINT_GRIPPER,   "Gripper",   5, "SG90",   10,  90,  28, 0, SG90_MIN_PULSE_US,   SG90_MAX_PULSE_US,   28.0f, 28.0f }
};

#endif // JOINT_CONFIG_H
