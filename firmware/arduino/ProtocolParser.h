#ifndef PROTOCOL_PARSER_H
#define PROTOCOL_PARSER_H

#include <Arduino.h>
#include "JointConfig.h"
#include "SafetyController.h"
#include "MotionEngine.h"
#include "PCA9685_Driver.h"

#define PROTOCOL_BUFFER_SIZE 64

class ProtocolParser {
public:
    ProtocolParser(SafetyController& safety, MotionEngine& motion, PCA9685_Driver& driver);

    void processIncomingChar(char c, Stream& responseStream);
    void parseCommandLine(const char* line, Stream& responseStream);
    void sendStatus(Stream& out);
    void sendCalibration(Stream& out);

private:
    SafetyController& m_safety;
    MotionEngine& m_motion;
    PCA9685_Driver& m_driver;

    char m_buffer[PROTOCOL_BUFFER_SIZE];
    uint8_t m_bufferIndex;
    uint8_t m_selectedJoint;

    bool parsePoseArgs(const char* args, float targets[NUM_JOINTS]);
};

#endif // PROTOCOL_PARSER_H
