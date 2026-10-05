#include "SafetyController.h"

SafetyController::SafetyController(PCA9685_Driver& driver)
    : m_driver(driver),
      m_state(STATE_DISCONNECTED),
      m_lastHeartbeatMillis(0),
      m_isMoving(false) {
}

void SafetyController::begin() {
    m_state = STATE_DISCONNECTED;
    m_isMoving = false;
    m_lastHeartbeatMillis = millis();
}

void SafetyController::feedWatchdog(uint32_t currentMillis) {
    m_lastHeartbeatMillis = currentMillis;
}

void SafetyController::setMoving(bool moving) {
    m_isMoving = moving;
    if (m_state == STATE_ESTOP) return;

    if (m_isMoving) {
        m_state = STATE_MOVING;
    } else if (m_state == STATE_MOVING) {
        m_state = STATE_READY;
    }
}

void SafetyController::update(uint32_t currentMillis) {
    if (m_state == STATE_ESTOP) {
        return;
    }

    // If moving or ready, check for timeout
    if (m_state == STATE_MOVING || m_state == STATE_READY) {
        if (currentMillis - m_lastHeartbeatMillis > TIMEOUT_MS) {
            // Watchdog expired during communication or motion
            if (m_isMoving) {
                triggerStop();
                m_state = STATE_STOPPED;
            }
        }
    }
}

bool SafetyController::handleHello() {
    if (m_state == STATE_ESTOP) {
        return false;
    }
    m_lastHeartbeatMillis = millis();
    m_state = STATE_HANDSHAKE_WAIT_STATUS;
    return true;
}

bool SafetyController::handleStatus() {
    if (m_state == STATE_ESTOP) {
        return true; // Status can still be queried during ESTOP
    }
    m_lastHeartbeatMillis = millis();
    if (m_state == STATE_HANDSHAKE_WAIT_STATUS) {
        m_state = STATE_HANDSHAKE_WAIT_ACK;
    }
    return true;
}

bool SafetyController::handleReadyAck() {
    if (m_state == STATE_ESTOP) {
        return false;
    }
    m_lastHeartbeatMillis = millis();
    if (m_state == STATE_HANDSHAKE_WAIT_ACK || m_state == STATE_STOPPED) {
        m_state = STATE_READY;
        return true;
    }
    return (m_state == STATE_READY);
}

bool SafetyController::canMove() const {
    if (m_state == STATE_ESTOP) return false;
    return (m_state == STATE_READY || m_state == STATE_MOVING || m_state == STATE_STOPPED);
}

void SafetyController::triggerStop() {
    if (m_state == STATE_ESTOP) return;
    m_isMoving = false;
    m_state = STATE_STOPPED;
}

void SafetyController::triggerEstop() {
    m_isMoving = false;
    m_state = STATE_ESTOP;
    m_driver.stopAll(); // Shuts down PWM outputs
}

bool SafetyController::resetEstop() {
    if (m_state == STATE_ESTOP) {
        m_state = STATE_STOPPED;
        m_lastHeartbeatMillis = millis();
        return true;
    }
    return false;
}

bool SafetyController::validateJointId(uint8_t jointId) const {
    return jointId < NUM_JOINTS;
}

bool SafetyController::validateAngle(uint8_t jointId, float angle, float& clampedAngle) const {
    if (jointId >= NUM_JOINTS) return false;

    const JointCalibration& j = g_joints[jointId];
    clampedAngle = angle;

    if (clampedAngle < (float)j.safeMin) {
        clampedAngle = (float)j.safeMin;
        return false; // Clamped due to limit violation
    }
    if (clampedAngle > (float)j.safeMax) {
        clampedAngle = (float)j.safeMax;
        return false; // Clamped due to limit violation
    }
    return true;
}

const char* SafetyController::getStateString() const {
    switch (m_state) {
        case STATE_DISCONNECTED: return "DISCONNECTED";
        case STATE_CONNECTED: return "CONNECTED";
        case STATE_HANDSHAKE_WAIT_STATUS: return "WAIT_STATUS";
        case STATE_HANDSHAKE_WAIT_ACK: return "WAIT_ACK";
        case STATE_READY: return "READY";
        case STATE_MOVING: return "MOVING";
        case STATE_STOPPED: return "STOPPED";
        case STATE_ESTOP: return "ESTOP";
        case STATE_ERROR: default: return "ERROR";
    }
}
