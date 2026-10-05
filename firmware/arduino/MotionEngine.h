#ifndef MOTION_ENGINE_H
#define MOTION_ENGINE_H

#include <Arduino.h>
#include "JointConfig.h"
#include "PCA9685_Driver.h"
#include "SafetyController.h"

enum MotionMode {
    MOTION_IDLE,
    MOTION_MANUAL,
    MOTION_POSE,
    MOTION_HOMING
};

enum SpeedProfile {
    SPEED_SLOW   = 1,
    SPEED_NORMAL = 2,
    SPEED_FAST   = 3
};

class MotionEngine {
public:
    MotionEngine(PCA9685_Driver& driver, SafetyController& safety);

    void begin();
    void update(uint32_t currentMillis);

    // Speed setting
    void setSpeedProfile(SpeedProfile speed);
    SpeedProfile getSpeedProfile() const { return m_speedProfile; }

    // Manual motion (Mode A)
    bool startManualJog(uint8_t jointId, int8_t direction); // +1 or -1
    void stopManualJog(uint8_t jointId);
    void stopAllManual();

    // Coordinated target motion (Mode B)
    bool setTargetPose(const float targets[NUM_JOINTS]);
    bool startTargetMove();

    // Safe Home motion
    bool startHoming();

    // Cancellation
    void stopMotion();

    MotionMode getMode() const { return m_mode; }
    bool isMoving() const { return m_mode != MOTION_IDLE; }

private:
    PCA9685_Driver& m_driver;
    SafetyController& m_safety;

    MotionMode m_mode;
    SpeedProfile m_speedProfile;

    // Timing
    uint32_t m_lastUpdateMillis;
    static const uint32_t UPDATE_INTERVAL_MS = 20; // 50 Hz motion loop

    // Manual jog state
    int8_t m_manualDirections[NUM_JOINTS];

    // Coordinated pose interpolation state
    float m_startAngles[NUM_JOINTS];
    float m_targetAngles[NUM_JOINTS];
    uint16_t m_totalSteps;
    uint16_t m_currentStep;

    float getStepIncrementDeg() const;
    void stepCoordinatedPose();
    void stepManualJog();
};

#endif // MOTION_ENGINE_H
