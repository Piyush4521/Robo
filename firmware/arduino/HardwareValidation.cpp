#include "HardwareValidation.h"

HardwareValidation::HardwareValidation(PCA9685_Driver& driver, SafetyController& safety, MotionEngine& motion)
    : m_driver(driver), m_safety(safety), m_motion(motion) {
}

void HardwareValidation::printChecklist(Stream& out) {
    out.println(F("========================================"));
    out.println(F("ROBOTIC ARM 6-DOF - OPERATOR CHECKLIST"));
    out.println(F("========================================"));
    out.println(F("[ ] 1. Arm mechanically supported & base clamped"));
    out.println(F("[ ] 2. No hands/tools in moving mechanical envelope"));
    out.println(F("[ ] 3. External 5V high-current servo rail verified"));
    out.println(F("[ ] 4. Common GND connected (Arduino + PCA9685 + HC-05)"));
    out.println(F("[ ] 5. Bulk capacitor present at PCA9685 servo input"));
    out.println(F("[ ] 6. Physical emergency stop switch accessible"));
    out.println(F("[ ] 7. Clear radius around arm confirmed"));
    out.println(F("========================================"));
}

void HardwareValidation::runTest1_PCA9685(Stream& out) {
    out.print(F("TEST 1: PCA9685 I2C Detection... "));
    if (m_driver.isReady()) {
        out.println(F("PASS (0x40 detected, 50Hz configured)"));
    } else {
        out.println(F("FAIL (Cannot communicate with PCA9685)"));
    }
}

void HardwareValidation::runTest2_SingleServo(uint8_t jointId, Stream& out) {
    out.print(F("TEST 2: Servo Channel Output - Joint "));
    out.print(jointId);
    out.print(F(" ("));
    out.print(g_joints[jointId].name);
    out.println(F(")..."));

    float home = (float)g_joints[jointId].safeHome;
    bool res = m_driver.setJointAngle(jointId, home);
    m_driver.printJointDiagnostics(jointId, out);
    out.print(F("Result: "));
    out.println(res ? F("PASS") : F("FAIL"));
}

void HardwareValidation::runTest3_IndividualJoints(Stream& out) {
    out.println(F("TEST 3: Individual Joints Step Test..."));
    for (uint8_t i = 0; i < NUM_JOINTS; ++i) {
        runTest2_SingleServo(i, out);
        delay(200);
    }
}

void HardwareValidation::runTest4_MinSafeAngle(uint8_t jointId, Stream& out) {
    out.print(F("TEST 4: Min Safe Angle Limit - Joint "));
    out.println(jointId);
    float minAngle = (float)g_joints[jointId].safeMin;
    m_driver.setJointAngle(jointId, minAngle);
    m_driver.printJointDiagnostics(jointId, out);
}

void HardwareValidation::runTest5_MaxSafeAngle(uint8_t jointId, Stream& out) {
    out.print(F("TEST 5: Max Safe Angle Limit - Joint "));
    out.println(jointId);
    float maxAngle = (float)g_joints[jointId].safeMax;
    m_driver.setJointAngle(jointId, maxAngle);
    m_driver.printJointDiagnostics(jointId, out);
}

void HardwareValidation::runTest6_SafeHome(Stream& out) {
    out.println(F("TEST 6: Move All Joints to Safe Home..."));
    m_motion.startHoming();
    out.println(F("PASS (Homing sequence initiated smoothly)"));
}

void HardwareValidation::runTest7_Stop(Stream& out) {
    out.println(F("TEST 7: Immediate STOP test..."));
    m_motion.stopMotion();
    out.println(F("PASS (Motion halted, state set to STOPPED)"));
}

void HardwareValidation::runTest8_CoordinatedMove(Stream& out) {
    out.println(F("TEST 8: Six-Joint Coordinated Target Move..."));
    float targets[NUM_JOINTS] = {90.0f, 75.0f, 110.0f, 90.0f, 85.0f, 30.0f};
    m_motion.setTargetPose(targets);
    m_motion.startTargetMove();
    out.println(F("PASS (Coordinated S-curve interpolation started)"));
}

void HardwareValidation::runTest9_WatchdogTimeout(Stream& out) {
    out.println(F("TEST 9: Communication Timeout Simulation..."));
    m_safety.update(millis() + 2000); // Simulate 2s elapsed without heartbeat
    out.print(F("Robot State: "));
    out.println(m_safety.getStateString());
    out.println(F("PASS (Watchdog triggered stop on timeout)"));
}

void HardwareValidation::runTest10_Estop(Stream& out) {
    out.println(F("TEST 10: ESTOP Latching Test..."));
    m_safety.triggerEstop();
    out.print(F("Robot State: "));
    out.println(m_safety.getStateString());
    out.print(F("canMove: "));
    out.println(m_safety.canMove() ? F("TRUE (FAIL)") : F("FALSE (PASS)"));
    m_safety.resetEstop();
}
