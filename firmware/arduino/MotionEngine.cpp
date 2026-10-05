#include "MotionEngine.h"

MotionEngine::MotionEngine(PCA9685_Driver& driver, SafetyController& safety)
    : m_driver(driver),
      m_safety(safety),
      m_mode(MOTION_IDLE),
      m_speedProfile(SPEED_NORMAL),
      m_lastUpdateMillis(0),
      m_totalSteps(0),
      m_currentStep(0) {
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        m_manualDirections[i] = 0;
        m_startAngles[i] = 90.0f;
        m_targetAngles[i] = 90.0f;
    }
}

void MotionEngine::begin() {
    m_mode = MOTION_IDLE;
    m_lastUpdateMillis = millis();
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        m_manualDirections[i] = 0;
        m_startAngles[i] = g_joints[i].commandedAngle;
        m_targetAngles[i] = g_joints[i].commandedAngle;
    }
}

void MotionEngine::setSpeedProfile(SpeedProfile speed) {
    if (speed >= SPEED_SLOW && speed <= SPEED_FAST) {
        m_speedProfile = speed;
    }
}

float MotionEngine::getStepIncrementDeg() const {
    switch (m_speedProfile) {
        case SPEED_SLOW:   return 0.4f; // 0.4 deg per 20ms = 20 deg/s
        case SPEED_FAST:   return 1.6f; // 1.6 deg per 20ms = 80 deg/s
        case SPEED_NORMAL:
        default:           return 0.8f; // 0.8 deg per 20ms = 40 deg/s
    }
}

bool MotionEngine::startManualJog(uint8_t jointId, int8_t direction) {
    if (!m_safety.canMove() || jointId >= NUM_JOINTS) {
        return false;
    }

    if (direction > 0) direction = 1;
    else if (direction < 0) direction = -1;
    else direction = 0;

    m_manualDirections[jointId] = direction;

    // Check if any joint is actively jogging
    bool anyJog = false;
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        if (m_manualDirections[i] != 0) {
            anyJog = true;
            break;
        }
    }

    if (anyJog) {
        m_mode = MOTION_MANUAL;
        m_safety.setMoving(true);
    } else {
        if (m_mode == MOTION_MANUAL) {
            m_mode = MOTION_IDLE;
            m_safety.setMoving(false);
        }
    }

    return true;
}

void MotionEngine::stopManualJog(uint8_t jointId) {
    if (jointId < NUM_JOINTS) {
        m_manualDirections[jointId] = 0;
    }
    bool anyJog = false;
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        if (m_manualDirections[i] != 0) {
            anyJog = true;
            break;
        }
    }
    if (!anyJog && m_mode == MOTION_MANUAL) {
        m_mode = MOTION_IDLE;
        m_safety.setMoving(false);
    }
}

void MotionEngine::stopAllManual() {
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        m_manualDirections[i] = 0;
    }
    if (m_mode == MOTION_MANUAL) {
        m_mode = MOTION_IDLE;
        m_safety.setMoving(false);
    }
}

bool MotionEngine::setTargetPose(const float targets[NUM_JOINTS]) {
    if (!m_safety.canMove()) return false;

    // Validate all targets against joint limits
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        float clamped;
        m_safety.validateAngle(i, targets[i], clamped);
        m_targetAngles[i] = clamped;
        g_joints[i].targetAngle = clamped;
    }
    return true;
}

bool MotionEngine::startTargetMove() {
    if (!m_safety.canMove()) return false;

    // Record start angles from current commanded positions
    float maxDiff = 0.0f;
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        m_startAngles[i] = g_joints[i].commandedAngle;
        float diff = abs(m_targetAngles[i] - m_startAngles[i]);
        if (diff > maxDiff) {
            maxDiff = diff;
        }
    }

    if (maxDiff < 0.2f) {
        // Already at target
        m_mode = MOTION_IDLE;
        m_safety.setMoving(false);
        return true;
    }

    // Calculate total steps based on maximum joint travel and speed increment
    float stepSize = getStepIncrementDeg();
    m_totalSteps = (uint16_t)(maxDiff / stepSize);
    if (m_totalSteps < 1) m_totalSteps = 1;

    m_currentStep = 0;
    m_mode = MOTION_POSE;
    m_safety.setMoving(true);
    return true;
}

bool MotionEngine::startHoming() {
    if (!m_safety.canMove()) return false;

    float homeTargets[NUM_JOINTS];
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        homeTargets[i] = (float)g_joints[i].safeHome;
    }

    setTargetPose(homeTargets);
    bool started = startTargetMove();
    if (started) {
        m_mode = MOTION_HOMING;
    }
    return started;
}

void MotionEngine::stopMotion() {
    stopAllManual();
    m_totalSteps = 0;
    m_currentStep = 0;
    m_mode = MOTION_IDLE;
    m_safety.setMoving(false);
    m_safety.triggerStop();
}

void MotionEngine::update(uint32_t currentMillis) {
    if (currentMillis - m_lastUpdateMillis < UPDATE_INTERVAL_MS) {
        return;
    }
    m_lastUpdateMillis = currentMillis;

    // ESTOP or safety failure stops all movement immediately
    if (m_safety.isEstop() || !m_safety.canMove()) {
        if (m_mode != MOTION_IDLE) {
            stopMotion();
        }
        return;
    }

    if (m_mode == MOTION_MANUAL) {
        stepManualJog();
    } else if (m_mode == MOTION_POSE || m_mode == MOTION_HOMING) {
        stepCoordinatedPose();
    }
}

void MotionEngine::stepManualJog() {
    float stepDeg = getStepIncrementDeg();

    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        int8_t dir = m_manualDirections[i];
        if (dir != 0) {
            float current = g_joints[i].commandedAngle;
            float requested = current + (float)dir * stepDeg;

            float clamped = requested;
            m_safety.validateAngle(i, requested, clamped);

            m_driver.setJointAngle(i, clamped);
        }
    }
}

void MotionEngine::stepCoordinatedPose() {
    if (m_currentStep < m_totalSteps) {
        m_currentStep++;
        float progress = (float)m_currentStep / (float)m_totalSteps;

        // Smooth cosine S-curve interpolation for jerk-free motion
        // s = (1 - cos(pi * progress)) / 2
        float smoothProgress = (1.0f - cos(PI * progress)) * 0.5f;

        for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
            float angle = m_startAngles[i] + (m_targetAngles[i] - m_startAngles[i]) * smoothProgress;
            m_driver.setJointAngle(i, angle);
        }

        if (m_currentStep >= m_totalSteps) {
            // Motion complete, ensure exact target values
            for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
                m_driver.setJointAngle(i, m_targetAngles[i]);
            }
            m_mode = MOTION_IDLE;
            m_safety.setMoving(false);
        }
    }
}
