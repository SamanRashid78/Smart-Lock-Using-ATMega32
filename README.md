# Smart Lock Using ATmega32

Password-based digital door lock built in AVR Assembly on ATmega32. Features 4×4 keypad input, 16×2 LCD feedback, and servo motor actuation. Validated in Proteus and implemented on hardware.

---

## How It Works

The user enters a 3-digit password via a 4×4 matrix keypad. Each keypress is echoed to a 16×2 LCD. Once 3 digits are entered, the firmware compares them against the hardcoded password. A correct match rotates a servo motor to unlock the door and displays "Door Unlocked". A wrong entry displays "Door Locked" and resets.

## Pin Map

| Signal | ATmega32 Port/Pin |
|---|---|
| Keypad rows/cols | PORTA (PA0–PA7) |
| LCD data bus | PORTD (PD0–PD7) |
| LCD RS / RW / EN | PORTB PB0 / PB1 / PB2 |
| Servo signal | PORTC bit 0 (PC0) |

## Hardware

- ATmega32 microcontroller
- 4×4 matrix keypad
- 16×2 alphanumeric LCD
- SG90 servo motor
- USBasp programmer
- Breadboard + jumper wires

**Total BOM cost: ~2360 PKR**

## Password

Default password is `A C D` (hardcoded in `CHECK_PASS`). To change it, edit the three `CPI` comparisons in `main.asm`:

```asm
CPI R16, 'A'   ; 1st digit
CPI R16, 'C'   ; 2nd digit
CPI R16, 'D'   ; 3rd digit
```

> **Note:** Password is stored in plain SRAM with no encryption (suitable for academic use only).

## Building & Flashing

Assemble with AVR Studio / Microchip Studio (AVRASM2) or avr-as:

```bash
# Using avr-as + avr-ld
avr-as -mmcu=atmega32 -o main.o src/main.asm
avr-ld -m avr5 -o main.elf main.o
avr-objcopy -O ihex main.elf main.hex

# Flash with USBasp
avrdude -c usbasp -p m32 -U flash:w:main.hex
```

AVR Studio: open `src/main.asm` directly and use the built-in assembler targeting ATmega32.

## Simulation

Circuit was designed and validated in **Proteus Design Suite**. Refer to the project report for schematic screenshots.

## Repo Structure

```
smart-lock-atmega32/
├── src/
│   └── main.asm          # Full firmware source
├── docs/
│   └── lab_14_proj_report.pdf
├── .gitignore
└── README.md
```

## Known Limitations

- Password is hardcoded and not changeable at runtime
- No lockout after repeated wrong attempts
- Servo control uses software delay loops rather than hardware PWM
- No EEPROM persistence

## Future Enhancements

- EEPROM-based runtime password change
- RFID or fingerprint authentication
- Buzzer alarm after N failed attempts
- GSM/Wi-Fi remote monitoring
