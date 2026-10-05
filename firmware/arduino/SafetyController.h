#ifndef SAFETY_CONTROLLER_H
#define SAFETY_CONTROLLER_H

#include <Arduino.h>
#include "JointConfig.h"
#include "PCA9685_Driver.h"

enum RobotStateEnum {
    STATE_DISCONNECTED,
    STATE_CONNECTED,
    STATE_HANDSHAKE_WAIT_STATUS,
    STATE_HANDSHAKE_WAIT_ACK,
    STATE_READY,
    STATE_MOVING,
    STATE_STOPPED,
    STATE_ESTOP,
    STATE_ERROR
};

class SafetyController {
public:
    SafetyController(PCA9685_Driver& driver);

    void begin();
    void update(uint32_t currentMillis);

    // Handshake progression
    bool handleHello();
    bool handleStatus();
    bool handleReadyAck();

    // Safety checks
    bool canMove() const;
    bool isEstop() const { return m_state == STATE_ESTOP; }
    bool isReady() const { return m_state == STATE_READY || m_state == STATE_MOVING || m_state == STATE_STOPPED; }

    // Actions
    void triggerStop();
    void triggerEstop();
    bool resetEstop();

    // Keep-alive / Watchdog
    void feedWatchdog(uint32_t currentMillis);
    void setMoving(bool moving);

    // Limit and command validation
    bool validateJointId(uint8_t jointId) const;
    bool validateAngle(uint8_t jointId, float angle, float& clampedAngle) const;

    // State getters
    RobotStateEnum getState() const { return m_state; }
    const char* getStateString() const;

private:
    PCA9685_Driver& m_driver;
    RobotStateEnum m_state;
    uint32_t m_lastHeartbeatMillis;
    bool m_isMoving;
    static const uint32_t TIMEOUT_MS = 1500; // 1.5 seconds communication timeout
};

#endif // SAFETY_CONTROLLER_H
