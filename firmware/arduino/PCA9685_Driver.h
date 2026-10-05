#ifndef PCA9685_DRIVER_H
#define PCA9685_DRIVER_H

#include <Arduino.h>
#include <Wire.h>
#include "JointConfig.h"

// PCA9685 Registers
#define PCA9685_MODE1       0x00
#define PCA9685_MODE2       0x01
#define PCA9685_PRESCALE    0xFE
#define PCA9685_LED0_ON_L   0x06
#define PCA9685_ALL_LED_OFF_H 0xFD

class PCA9685_Driver {
public:
    PCA9685_Driver(uint8_t i2cAddress = PCA9685_I2C_ADDR);

    bool initialize(uint16_t freqHz = SERVO_FREQ_HZ);
    bool setJointAngle(uint8_t jointId, float requestedAngle);
    float getCommandedAngle(uint8_t jointId) const;
    void stopAll();
    bool isReady() const { return m_initialized; }

    void printJointDiagnostics(uint8_t jointId, Stream& out);

private:
    uint8_t m_address;
    uint16_t m_freqHz;
    bool m_initialized;

    void writeRegister(uint8_t reg, uint8_t value);
    uint8_t readRegister(uint8_t reg);
    void setPWM(uint8_t channel, uint16_t onTick, uint16_t offTick);
    uint16_t angleToTicks(uint8_t jointId, float angle);
};

#endif // PCA9685_DRIVER_H
