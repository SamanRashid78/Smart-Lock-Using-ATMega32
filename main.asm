;   SMART LOCK SYSTEM - ATmega32 (AVR Assembly)
.include "m32def.inc"

; LCD PIN DEFINITIONS 
.EQU LCD_DPRT = PORTD       ; LCD DATA PORT
.EQU LCD_DDDR = DDRD        ; LCD DATA DDR
.EQU LCD_DPIN = PIND        ; LCD DATA PIN

.EQU LCD_CPRT = PORTB       ; LCD COMMANDS PORT
.EQU LCD_CDDR = DDRB        ; LCD COMMANDS DDR
.EQU LCD_CPIN = PINB        ; LCD COMMANDS PIN

.EQU LCD_RS   = 0           ; LCD RS  -> PB0
.EQU LCD_RW   = 1           ; LCD RW  -> PB1
.EQU LCD_EN   = 2           ; LCD EN  -> PB2

; KEYPAD DEFINITIONS 
.EQU KEY_PORT = PORTA
.EQU KEY_PIN  = PINA
.EQU KEY_DDR  = DDRA

; SERVO DEFINITION 
.EQU SERVO_PIN = 0          ; Servo on Port C Bit 0

; RAM VARIABLES 
.DSEG
INPUT_BUF: .BYTE 4          ; Reserve 4 bytes for user input

; RESET VECTOR
.CSEG
.ORG 0x0000
    RJMP MAIN

; MAIN - Initialization
MAIN:
    ; 1. STACK SETUP 
    LDI R21, HIGH(RAMEND)
    OUT SPH, R21
    LDI R21, LOW(RAMEND)
    OUT SPL, R21

    ; 2. SERVO INIT (PORTC) 
    SBI DDRC, SERVO_PIN     ; Set PC0 as Output
    CBI PORTC, SERVO_PIN

    ; 3. LCD INITIALIZATION 
    LDI R21, 0xFF
    OUT LCD_DDDR, R21
    OUT LCD_CDDR, R21
    CBI LCD_CPRT, LCD_EN
    CALL DELAY_2ms
    LDI R16, 0x38           ; 8-bit, 2-line, 5x7 font
    CALL CMNDWRT
    CALL DELAY_2ms
    LDI R16, 0x0E           ; display on, cursor on
    CALL CMNDWRT
    LDI R16, 0x01           ; clear LCD
    CALL CMNDWRT
    CALL DELAY_2ms
    LDI R16, 0x06           ; entry mode: increment, no shift
    CALL CMNDWRT

    ; 4. KEYPAD INITIALIZATION 
    LDI R20, 0x0F
    OUT KEY_DDR, R20        ; upper nibble = output (rows), lower = input (cols)

; SYSTEM_RESET - Re-entry point after wrong/correct attempt
SYSTEM_RESET:
    ; Reset Input Index Counter (R22)
    LDI R22, 0

    ; Display "Enter Password:"
    LDI R16, 0x01           ; Clear Screen
    CALL CMNDWRT
    CALL DELAY_2ms

    LDI ZL, LOW(MSG_ENTER*2)
    LDI ZH, HIGH(MSG_ENTER*2)
    CALL SEND_STRING

    ; Move Cursor to 2nd Line
    LDI R16, 0xC0
    CALL CMNDWRT

; KEYPAD SCAN LOOP
GROUND_ALL_ROWS:
    LDI R20, 0xF0
    OUT KEY_PORT, R20

WAIT_FOR_RELEASE:
    NOP
    IN  R21, KEY_PIN
    ANDI R21, 0xF0
    CPI R21, 0xF0
    BRNE WAIT_FOR_RELEASE

WAIT_FOR_KEY:
    NOP
    IN  R21, KEY_PIN
    ANDI R21, 0xF0
    CPI R21, 0xF0
    BREQ WAIT_FOR_KEY

    CALL WAIT15MS           ; Debounce delay

    IN  R21, KEY_PIN
    ANDI R21, 0xF0
    CPI R21, 0xF0
    BREQ WAIT_FOR_KEY

    ; SCAN ROW 0 (PA0) 
    LDI R21, 0b11111110
    OUT KEY_PORT, R21
    NOP
    IN  R21, KEY_PIN
    ANDI R21, 0xF0
    CPI R21, 0xF0
    BRNE ROW_0_FOUND

    ; SCAN ROW 1 (PA1) 
    LDI R21, 0b11111101
    OUT KEY_PORT, R21
    NOP
    IN  R21, KEY_PIN
    ANDI R21, 0xF0
    CPI R21, 0xF0
    BRNE ROW_1_FOUND

    ; SCAN ROW 2 (PA2) 
    LDI R21, 0b11111011
    OUT KEY_PORT, R21
    NOP
    IN  R21, KEY_PIN
    ANDI R21, 0xF0
    CPI R21, 0xF0
    BRNE ROW_2_FOUND

    ; SCAN ROW 3 (PA3) 
    LDI R21, 0b11110111
    OUT KEY_PORT, R21
    NOP
    IN  R21, KEY_PIN
    ANDI R21, 0xF0
    CPI R21, 0xF0
    BRNE ROW_3_FOUND

    RJMP GROUND_ALL_ROWS    ; No key found, retry

; ROW HANDLERS - Load Z pointer to correct keycode table
ROW_0_FOUND:
    LDI R30, LOW(KCODE0<<1)
    LDI R31, HIGH(KCODE0<<1)
    RJMP FIND_PREP

ROW_1_FOUND:
    LDI R30, LOW(KCODE1<<1)
    LDI R31, HIGH(KCODE1<<1)
    RJMP FIND_PREP

ROW_2_FOUND:
    LDI R30, LOW(KCODE2<<1)
    LDI R31, HIGH(KCODE2<<1)
    RJMP FIND_PREP

ROW_3_FOUND:
    LDI R30, LOW(KCODE3<<1)
    LDI R31, HIGH(KCODE3<<1)
    RJMP FIND_PREP

; FIND COLUMN LOOP - Shift column bits to identify pressed key
FIND_PREP:
    SWAP R21                ; Move column nibble to lower nibble

FIND:
    LSR R21
    BRCC MATCH              ; Carry clear = this column is active
    LPM R20, Z+             ; Skip this entry, advance table pointer
    RJMP FIND

; MATCH - Key identified; display and store it
MATCH:
    LPM R16, Z              ; Load key character from table
    CALL DATAWRT            ; Display character on LCD

    ; Store key in buffer
    LDI XL, LOW(INPUT_BUF)
    LDI XH, HIGH(INPUT_BUF)
    ADD XL, R22             ; Offset by input count
    ADC XH, R1              ; Add carry (R1 = 0)
    ST  X, R16              ; Store character

    INC R22                 ; Increment input counter
    CPI R22, 3              ; Check if 3 digits entered
    BREQ CHECK_PASS         ; If yes, verify password

    RJMP GROUND_ALL_ROWS    ; Else, get next key

; CHECK_PASS: we use it to compare entered digits against hardcoded password
CHECK_PASS:
    CALL DELAY_2ms

    ; Reset X pointer to start of buffer
    LDI XL, LOW(INPUT_BUF)
    LDI XH, HIGH(INPUT_BUF)

    ; Check 1st Digit (Hardcoded 'A')
    LD  R16, X+
    CPI R16, 'A'
    BRNE WRONG_CODE

    ; Check 2nd Digit (Hardcoded 'C')
    LD  R16, X+
    CPI R16, 'C'
    BRNE WRONG_CODE

    ; Check 3rd Digit (Hardcoded 'D')
    LD  R16, X+
    CPI R16, 'D'
    BRNE WRONG_CODE

    RJMP OPEN_DOOR

; WRONG_CODE: Display "Door Locked" and reset
WRONG_CODE:
    LDI R16, 0x01           ; Clear LCD
    CALL CMNDWRT
    CALL DELAY_2ms

    LDI ZL, LOW(MSG_WRONG*2)
    LDI ZH, HIGH(MSG_WRONG*2)
    CALL SEND_STRING

    CALL DELAY_LONG         ; Wait so user can see message
    RJMP SYSTEM_RESET

; OPEN_DOOR: Display unlock messages and rotate servo
OPEN_DOOR:
    LDI R16, 0x01           ; Clear LCD
    CALL CMNDWRT
    CALL DELAY_2ms

    LDI ZL, LOW(MSG_CORRECT*2)
    LDI ZH, HIGH(MSG_CORRECT*2)
    CALL SEND_STRING

    LDI R16, 0xC0           ; New Line
    CALL CMNDWRT

    LDI ZL, LOW(MSG_OPENING*2)
    LDI ZH, HIGH(MSG_OPENING*2)
    CALL SEND_STRING

    ; ROTATE SERVO (90 Degrees) 
    LDI R23, 50             ; Repeat 50 times (~1 second)

SERVO_LOOP:
    SBI DDRC,  SERVO_PIN
    SBI PORTC, SERVO_PIN    ; High for 2ms
    CALL DELAY_2ms
    CBI PORTC, SERVO_PIN    ; Low for 18ms
    CALL DELAY_18ms
    DEC R23
    BRNE SERVO_LOOP

    ; SHOW DOOR UNLOCKED 
    LDI R16, 0x01           ; Clear LCD
    CALL CMNDWRT
    CALL DELAY_2ms

    LDI ZL, LOW(MSG_UNLOCKED*2)
    LDI ZH, HIGH(MSG_UNLOCKED*2)
    CALL SEND_STRING

STOP: RJMP STOP             ; Halt (door stays unlocked)

; LCD SUBROUTINES
CMNDWRT:
    OUT LCD_DPRT, R16
    CBI LCD_CPRT, LCD_RS
    CBI LCD_CPRT, LCD_RW
    SBI LCD_CPRT, LCD_EN
    CALL SDELAY
    CBI LCD_CPRT, LCD_EN
    CALL DELAY_100us
    RET

DATAWRT:
    OUT LCD_DPRT, R16
    SBI LCD_CPRT, LCD_RS
    CBI LCD_CPRT, LCD_RW
    SBI LCD_CPRT, LCD_EN
    CALL SDELAY
    CBI LCD_CPRT, LCD_EN
    CALL DELAY_100us
    RET

SEND_STRING:
    LPM R16, Z+
    CPI R16, 0              ; Null terminator
    BREQ STR_END
    CALL DATAWRT
    RJMP SEND_STRING
STR_END:
    RET

; DELAY SUBROUTINES
SDELAY:
    NOP
    NOP
    RET

DELAY_100us:
    PUSH R17
    LDI R17, 60
DR0:
    CALL SDELAY
    DEC R17
    BRNE DR0
    POP R17
    RET

DELAY_2ms:
    PUSH R17
    LDI R17, 20
LDR0:
    CALL DELAY_100US
    DEC R17
    BRNE LDR0
    POP R17
    RET

; Servo delays
DELAY_18ms:
    PUSH R17
    LDI R17, 9
D18_LOOP:
    CALL DELAY_2ms
    DEC R17
    BRNE D18_LOOP
    POP R17
    RET

DELAY_LONG:
    PUSH R18
    LDI R18, 100
DL_LOOP:
    CALL DELAY_18ms
    DEC R18
    BRNE DL_LOOP
    POP R18
    RET

WAIT15MS:
    PUSH R17
    LDI R17, 8
W_LOOP:
    CALL DELAY_2ms
    DEC R17
    BRNE W_LOOP
    POP R17
    RET

; LOOKUP TABLES (HARDWARE SPECIFIC)
.ORG 0x300

KCODE0: .DB '1','2','3','A'
KCODE1: .DB '4','5','6','B'
KCODE2: .DB '7','8','9','C'
KCODE3: .DB '*','0','#','D'

; String constants (null-terminated)
MSG_ENTER:    .DB "Enter Password:", 0
MSG_WRONG:    .DB "Door Locked", 0
MSG_CORRECT:  .DB "WELCOME", 0
MSG_OPENING:  .DB "Motor On", 0
MSG_UNLOCKED: .DB "Door Unlocked", 0
