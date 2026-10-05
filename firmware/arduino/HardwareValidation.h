#ifndef HARDWARE_VALIDATION_H
#define HARDWARE_VALIDATION_H

#include <Arduino.h>
#include "JointConfig.h"
#include "PCA9685_Driver.h"
#include "SafetyController.h"
#include "MotionEngine.h"

class HardwareValidation {
public:
    HardwareValidation(PCA9685_Driver& driver, SafetyController& safety, MotionEngine& motion);

    void printChecklist(Stream& out);
    void runTest1_PCA9685(Stream& out);
    void runTest2_SingleServo(uint8_t jointId, Stream& out);
    void runTest3_IndividualJoints(Stream& out);
    void runTest4_MinSafeAngle(uint8_t jointId, Stream& out);
    void runTest5_MaxSafeAngle(uint8_t jointId, Stream& out);
    void runTest6_SafeHome(Stream& out);
    void runTest7_Stop(Stream& out);
    void runTest8_CoordinatedMove(Stream& out);
    void runTest9_WatchdogTimeout(Stream& out);
    void runTest10_Estop(Stream& out);

private:
    PCA9685_Driver& m_driver;
    SafetyController& m_safety;
    MotionEngine& m_motion;
};

#endif // HARDWARE_VALIDATION_H
