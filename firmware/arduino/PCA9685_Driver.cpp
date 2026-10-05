#include "PCA9685_Driver.h"

PCA9685_Driver::PCA9685_Driver(uint8_t i2cAddress)
    : m_address(i2cAddress), m_freqHz(SERVO_FREQ_HZ), m_initialized(false) {
}

bool PCA9685_Driver::initialize(uint16_t freqHz) {
    m_freqHz = freqHz;
    Wire.begin();

    // Check device presence on I2C
    Wire.beginTransmission(m_address);
    if (Wire.endTransmission() != 0) {
        m_initialized = false;
        return false;
    }

    // Reset MODE1
    writeRegister(PCA9685_MODE1, 0x00);
    delay(5);

    // Set PWM frequency
    // prescale = round(25MHz / (4096 * freq)) - 1
    float prescaleval = 25000000.0f;
    prescaleval /= 4096.0f;
    prescaleval /= (float)freqHz;
    prescaleval -= 1.0f;
    uint8_t prescale = (uint8_t)(prescaleval + 0.5f);

    uint8_t oldmode = readRegister(PCA9685_MODE1);
    uint8_t newmode = (oldmode & 0x7F) | 0x10; // sleep mode to set prescaler

    writeRegister(PCA9685_MODE1, newmode);
    writeRegister(PCA9685_PRESCALE, prescale);
    writeRegister(PCA9685_MODE1, oldmode);
    delay(5);
    // Restart with auto-increment enabled (0xA1 = RESTART | AI | ALLCALL)
    writeRegister(PCA9685_MODE1, oldmode | 0xA0);

    m_initialized = true;
    return true;
}

void PCA9685_Driver::writeRegister(uint8_t reg, uint8_t value) {
    Wire.beginTransmission(m_address);
    Wire.write(reg);
    Wire.write(value);
    Wire.endTransmission();
}

uint8_t PCA9685_Driver::readRegister(uint8_t reg) {
    Wire.beginTransmission(m_address);
    Wire.write(reg);
    Wire.endTransmission();

    Wire.requestFrom(m_address, (uint8_t)1);
    if (Wire.available()) {
        return Wire.read();
    }
    return 0;
}

void PCA9685_Driver::setPWM(uint8_t channel, uint16_t onTick, uint16_t offTick) {
    if (channel > 15) return;
    uint8_t regBase = PCA9685_LED0_ON_L + 4 * channel;

    Wire.beginTransmission(m_address);
    Wire.write(regBase);
    Wire.write((uint8_t)(onTick & 0xFF));
    Wire.write((uint8_t)((onTick >> 8) & 0xFF));
    Wire.write((uint8_t)(offTick & 0xFF));
    Wire.write((uint8_t)((offTick >> 8) & 0xFF));
    Wire.endTransmission();
}

uint16_t PCA9685_Driver::angleToTicks(uint8_t jointId, float angle) {
    if (jointId >= NUM_JOINTS) return 0;

    JointCalibration& j = g_joints[jointId];

    // Safe limit enforcement
    float validated = angle;
    if (validated < j.safeMin) validated = j.safeMin;
    if (validated > j.safeMax) validated = j.safeMax;

    // Apply offset
    float calibrated = validated + j.offset;
    if (calibrated < 0.0f) calibrated = 0.0f;
    if (calibrated > 180.0f) calibrated = 180.0f;

    // Map 0 - 180 degrees to minPulseUs - maxPulseUs
    float pulseUs = (float)j.minPulseUs + (calibrated / 180.0f) * (float)(j.maxPulseUs - j.minPulseUs);

    // 50Hz = 20,000 microseconds per cycle. 4096 ticks per cycle.
    // ticks = pulseUs * 4096 / 20000
    uint16_t ticks = (uint16_t)((pulseUs * 4096.0f) / 20000.0f);
    return ticks;
}

bool PCA9685_Driver::setJointAngle(uint8_t jointId, float requestedAngle) {
    if (!m_initialized || jointId >= NUM_JOINTS) return false;

    JointCalibration& j = g_joints[jointId];

    // Stage 1: Requested angle
    // Stage 2: Validated angle (clamped to safe limits)
    float validatedAngle = requestedAngle;
    if (validatedAngle < (float)j.safeMin) validatedAngle = (float)j.safeMin;
    if (validatedAngle > (float)j.safeMax) validatedAngle = (float)j.safeMax;

    // Stage 3: Calculate ticks (incorporates offset and microsecond pulse mapping)
    uint16_t ticks = angleToTicks(jointId, validatedAngle);

    // Stage 4: PWM output
    setPWM(j.channel, 0, ticks);

    // Record last commanded angle (OPEN-LOOP, NOT SENSOR MEASURED)
    j.commandedAngle = validatedAngle;

    return true;
}

float PCA9685_Driver::getCommandedAngle(uint8_t jointId) const {
    if (jointId >= NUM_JOINTS) return 0.0f;
    return g_joints[jointId].commandedAngle;
}

void PCA9685_Driver::stopAll() {
    if (!m_initialized) return;
    // Turn off all PWM outputs on PCA9685 (bit 4 of ALL_LED_OFF_H = 1)
    Wire.beginTransmission(m_address);
    Wire.write(PCA9685_ALL_LED_OFF_H);
    Wire.write(0x10); // ALL_OFF bit
    Wire.endTransmission();
}

void PCA9685_Driver::printJointDiagnostics(uint8_t jointId, Stream& out) {
    if (jointId >= NUM_JOINTS) {
        out.println(F("ERR:INVALID_JOINT"));
        return;
    }
    JointCalibration& j = g_joints[jointId];
    out.print(F("JOINT:"));
    out.print(j.jointId);
    out.print(F(" NAME:"));
    out.print(j.name);
    out.print(F(" CH:"));
    out.print(j.channel);
    out.print(F(" SERVO:"));
    out.print(j.servoType);
    out.print(F(" MIN:"));
    out.print(j.safeMin);
    out.print(F(" MAX:"));
    out.print(j.safeMax);
    out.print(F(" HOME:"));
    out.print(j.safeHome);
    out.print(F(" OFFSET:"));
    out.print(j.offset);
    out.print(F(" COMMANDED:"));
    out.println(j.commandedAngle, 1);
}
