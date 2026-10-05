#include "ProtocolParser.h"
#include <string.h>
#include <stdlib.h>

ProtocolParser::ProtocolParser(SafetyController& safety, MotionEngine& motion, PCA9685_Driver& driver)
    : m_safety(safety),
      m_motion(motion),
      m_driver(driver),
      m_bufferIndex(0),
      m_selectedJoint(0) {
    m_buffer[0] = '\0';
}

void ProtocolParser::processIncomingChar(char c, Stream& responseStream) {
    if (c == '\r') {
        return; // Ignore carriage returns
    }
    if (c == '\n') {
        m_buffer[m_bufferIndex] = '\0';
        if (m_bufferIndex > 0) {
            parseCommandLine(m_buffer, responseStream);
        }
        m_bufferIndex = 0;
        return;
    }

    if (m_bufferIndex < PROTOCOL_BUFFER_SIZE - 1) {
        m_buffer[m_bufferIndex++] = c;
    } else {
        // Buffer overflow protection: reset and report error
        m_bufferIndex = 0;
        responseStream.println(F("ERR:BUFFER_OVERFLOW"));
    }
}

bool ProtocolParser::parsePoseArgs(const char* args, float targets[NUM_JOINTS]) {
    char temp[48];
    strncpy(temp, args, sizeof(temp) - 1);
    temp[sizeof(temp) - 1] = '\0';

    char* token = strtok(temp, ",");
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        if (!token) return false;
        targets[i] = (float)atof(token);
        token = strtok(NULL, ",");
    }
    return true;
}

void ProtocolParser::sendStatus(Stream& out) {
    out.print(F("STATE:"));
    out.print(m_safety.getStateString());
    out.print(F(",MOTION:"));
    switch (m_motion.getMode()) {
        case MOTION_MANUAL: out.print(F("MANUAL")); break;
        case MOTION_POSE:   out.print(F("MOVING_TO_TARGET")); break;
        case MOTION_HOMING: out.print(F("HOMING")); break;
        case MOTION_IDLE: default: out.print(F("IDLE")); break;
    }
    out.print(F(",SPD:"));
    out.print(m_motion.getSpeedProfile());
    out.print(F(",ANGLES:"));
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        out.print(g_joints[i].commandedAngle, 1);
        if (i < NUM_JOINTS - 1) out.print(',');
    }
    out.println();
}

void ProtocolParser::sendCalibration(Stream& out) {
    out.println(F("CALIBRATION_TABLE_BEGIN"));
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        m_driver.printJointDiagnostics(i, out);
    }
    out.println(F("CALIBRATION_TABLE_END"));
}

void ProtocolParser::parseCommandLine(const char* line, Stream& responseStream) {
    // Feed communication watchdog on any valid command line
    m_safety.feedWatchdog(millis());

    // 1. ESTOP (can be triggered at any time, in any state)
    if (strcmp(line, "ESTOP") == 0) {
        m_motion.stopMotion();
        m_safety.triggerEstop();
        responseStream.println(F("ACK:ESTOP"));
        return;
    }

    // 2. STOP (stops active motion immediately)
    if (strcmp(line, "STOP") == 0) {
        m_motion.stopMotion();
        m_safety.triggerStop();
        responseStream.println(F("ACK:STOP"));
        return;
    }

    // 3. RESET_ESTOP (explicit clearance of ESTOP)
    if (strcmp(line, "RESET_ESTOP") == 0) {
        if (m_safety.resetEstop()) {
            responseStream.println(F("ACK:RESET_ESTOP"));
        } else {
            responseStream.println(F("ERR:NOT_ESTOP"));
        }
        return;
    }

    // If currently in ESTOP state, reject any other commands
    if (m_safety.isEstop()) {
        responseStream.println(F("ERR:ESTOP"));
        return;
    }

    // 4. HELLO (Handshake Step 1)
    if (strcmp(line, "HELLO") == 0) {
        m_safety.handleHello();
        responseStream.println(F("ROBOT_6DOF_READY v1"));
        return;
    }

    // 5. STATUS? (Handshake Step 2 or periodic query)
    if (strcmp(line, "STATUS?") == 0) {
        m_safety.handleStatus();
        sendStatus(responseStream);
        return;
    }

    // 6. READY_ACK (Handshake Step 3)
    if (strcmp(line, "READY_ACK") == 0) {
        if (m_safety.handleReadyAck()) {
            responseStream.println(F("OK"));
        } else {
            responseStream.println(F("ERR:HANDSHAKE_FAILED"));
        }
        return;
    }

    // 7. PING
    if (strcmp(line, "PING") == 0) {
        responseStream.println(F("PONG"));
        return;
    }

    // 8. CALIB?
    if (strcmp(line, "CALIB?") == 0) {
        sendCalibration(responseStream);
        return;
    }

    // All motion and configuration commands require the robot to be READY
    if (!m_safety.isReady()) {
        responseStream.println(F("ERR:NOT_READY"));
        return;
    }

    // 9. Speed profile: SPD:1|2|3
    if (strncmp(line, "SPD:", 4) == 0) {
        int spd = atoi(line + 4);
        if (spd >= 1 && spd <= 3) {
            m_motion.setSpeedProfile((SpeedProfile)spd);
            responseStream.print(F("ACK:SPD:"));
            responseStream.println(spd);
        } else {
            responseStream.println(F("ERR:INVALID_SPEED"));
        }
        return;
    }

    // 10. Select Joint: SEL:0..5
    if (strncmp(line, "SEL:", 4) == 0) {
        int id = atoi(line + 4);
        if (id >= 0 && id < NUM_JOINTS) {
            m_selectedJoint = (uint8_t)id;
            responseStream.print(F("ACK:SEL:"));
            responseStream.println(id);
        } else {
            responseStream.println(F("ERR:INVALID_JOINT"));
        }
        return;
    }

    // 11. Manual Jog Positive: J+:id or J+
    if (strncmp(line, "J+:", 3) == 0 || strcmp(line, "J+") == 0) {
        uint8_t jointId = (line[2] == ':') ? (uint8_t)atoi(line + 3) : m_selectedJoint;
        if (jointId < NUM_JOINTS) {
            if (m_motion.startManualJog(jointId, 1)) {
                responseStream.print(F("ACK:J+:"));
                responseStream.println(jointId);
            } else {
                responseStream.println(F("ERR:CANNOT_MOVE"));
            }
        } else {
            responseStream.println(F("ERR:INVALID_JOINT"));
        }
        return;
    }

    // 12. Manual Jog Negative: J-:id or J-
    if (strncmp(line, "J-:", 3) == 0 || strcmp(line, "J-") == 0) {
        uint8_t jointId = (line[2] == ':') ? (uint8_t)atoi(line + 3) : m_selectedJoint;
        if (jointId < NUM_JOINTS) {
            if (m_motion.startManualJog(jointId, -1)) {
                responseStream.print(F("ACK:J-:"));
                responseStream.println(jointId);
            } else {
                responseStream.println(F("ERR:CANNOT_MOVE"));
            }
        } else {
            responseStream.println(F("ERR:INVALID_JOINT"));
        }
        return;
    }

    // 13. Stop Manual Jog: J0:id or J0
    if (strncmp(line, "J0:", 3) == 0 || strcmp(line, "J0") == 0) {
        uint8_t jointId = (line[2] == ':') ? (uint8_t)atoi(line + 3) : m_selectedJoint;
        if (jointId < NUM_JOINTS) {
            m_motion.stopManualJog(jointId);
            responseStream.print(F("ACK:J0:"));
            responseStream.println(jointId);
        } else {
            m_motion.stopAllManual();
            responseStream.println(F("ACK:J0:ALL"));
        }
        return;
    }

    // 14. Target Pose: POSE:b,s,e,l,w,g
    if (strncmp(line, "POSE:", 5) == 0) {
        float targets[NUM_JOINTS];
        if (parsePoseArgs(line + 5, targets)) {
            if (m_motion.setTargetPose(targets)) {
                responseStream.println(F("ACK:POSE"));
            } else {
                responseStream.println(F("ERR:LIMIT"));
            }
        } else {
            responseStream.println(F("ERR:INVALID_ARGS"));
        }
        return;
    }

    // 15. Execute Move to Target: MOVE
    if (strcmp(line, "MOVE") == 0) {
        if (m_motion.startTargetMove()) {
            responseStream.println(F("ACK:MOVE"));
        } else {
            responseStream.println(F("ERR:CANNOT_MOVE"));
        }
        return;
    }

    // 16. Move to Safe Home: HOME
    if (strcmp(line, "HOME") == 0) {
        if (m_motion.startHoming()) {
            responseStream.println(F("ACK:HOME"));
        } else {
            responseStream.println(F("ERR:CANNOT_MOVE"));
        }
        return;
    }

    // Unknown command
    responseStream.println(F("ERR:INVALID_COMMAND"));
}
