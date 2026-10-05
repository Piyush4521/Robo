#ifndef BOARD_PROFILE_H
#define BOARD_PROFILE_H

#include <Arduino.h>

// Board type identifiers
#define BOARD_TYPE_UNO   1
#define BOARD_TYPE_NANO  2
#define BOARD_TYPE_MEGA  3

// Board selection: Uncomment one or specify via compiler flag -DBOARD_TARGET=...
#ifndef TARGET_BOARD
  #if defined(__AVR_ATmega2560__)
    #define TARGET_BOARD BOARD_TYPE_MEGA
  #elif defined(__AVR_ATmega328P__)
    // Default 328P to UNO R3 (compatible with Nano)
    #define TARGET_BOARD BOARD_TYPE_UNO
  #else
    #define TARGET_BOARD BOARD_TYPE_UNO
  #endif
#endif

struct BoardProfile {
    const char* boardName;
    uint8_t boardType;
    uint8_t i2cSdaPin;
    uint8_t i2cSclPin;
    bool useHardwareBtSerial;
    uint8_t btRxPin;  // For SoftwareSerial
    uint8_t btTxPin;  // For SoftwareSerial
    long btBaudRate;
    long debugBaudRate;
};

// Compile-time board profiles
#if (TARGET_BOARD == BOARD_TYPE_MEGA)
  static const BoardProfile CURRENT_BOARD_PROFILE = {
      "Arduino Mega 2560",
      BOARD_TYPE_MEGA,
      20,       // SDA pin
      21,       // SCL pin
      true,     // Use Hardware Serial1
      19,       // RX1
      18,       // TX1
      9600,     // HC-05 Default Baud
      115200    // USB Debug Serial Baud
  };
#elif (TARGET_BOARD == BOARD_TYPE_NANO)
  static const BoardProfile CURRENT_BOARD_PROFILE = {
      "Arduino Nano (ATmega328P)",
      BOARD_TYPE_NANO,
      A4,       // SDA pin
      A5,       // SCL pin
      false,    // Use SoftwareSerial
      10,       // BT RX pin (Arduino pin 10 connects to HC-05 TX)
      11,       // BT TX pin (Arduino pin 11 connects to HC-05 RX via resistor divider)
      9600,     // HC-05 Default Baud
      115200    // USB Debug Serial Baud
  };
#else
  // Default to Arduino UNO R3
  static const BoardProfile CURRENT_BOARD_PROFILE = {
      "Arduino UNO R3",
      BOARD_TYPE_UNO,
      A4,       // SDA pin
      A5,       // SCL pin
      false,    // Use SoftwareSerial
      10,       // BT RX pin (Arduino pin 10 connects to HC-05 TX)
      11,       // BT TX pin (Arduino pin 11 connects to HC-05 RX via resistor divider)
      9600,     // HC-05 Default Baud
      115200    // USB Debug Serial Baud
  };
#endif

#endif // BOARD_PROFILE_H
