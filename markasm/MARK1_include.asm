; ---------------------------------
; MARK1_include.asm
;
; Created: 11/11/2023 11:40:49 AM
; Authors: FR & NN
; ---------------------------------
 

; ------------------------------------------------------
;                CONSTANTES AUXILIARES
; ------------------------------------------------------

.equ CLK_FREQUENCY = 16000000

.equ PWM_PERIOD_US  = 20000
.equ PWM_MAX_TON_US = 2500
.equ PWM_MIN_TON_US = 500

.equ BAUD_RATE = 9600


; ------------------------------------------------------
;                 CONSTANTES NUMÉRICAS
; ------------------------------------------------------

.equ MAX_STEPA = 20  ; Hay MAX_STEPA estados más el 0 = MAX_STEPA + 1 estados
.equ MAX_STEPB = 20  ; Hay MAX_STEPB estados más el 0 = MAX_STEPB + 1 estados
.equ STEPA_INICIAL = 10
.equ STEPB_INICIAL = 10

.equ TOP_PWM = int( (CLK_FREQUENCY/8) * PWM_PERIOD_US / (2 * 1000000) ) ; del datasheet

.equ MAX_OCR1A  = int(TOP_PWM - TOP_PWM * PWM_MIN_TON_US / PWM_PERIOD_US)
.equ MIN_OCR1A  = int(TOP_PWM - TOP_PWM * PWM_MAX_TON_US / PWM_PERIOD_US)
.equ STEP_OCR1A = (MAX_OCR1A - MIN_OCR1A) / MAX_STEPA

.equ MAX_OCR1B  = int(TOP_PWM - TOP_PWM * PWM_MIN_TON_US / PWM_PERIOD_US) 
.equ MIN_OCR1B  = int(TOP_PWM - TOP_PWM * PWM_MAX_TON_US / PWM_PERIOD_US)
.equ STEP_OCR1B = (MAX_OCR1B - MIN_OCR1B) / MAX_STEPB ; si llegaste acá, elegí valores que den todo entero bro

.equ UBRR0 = int( CLK_FREQUENCY / (16 * BAUD_RATE) - 1 )

; Medidos en overflows del timer 0 (16 ms)
.equ DELAY_MOVIMIENTO = 20
.equ DELAY_STEP       = 10
.equ DELAY_LASER      = 0xFF

; Objetivo: 10 us
.equ LOOPS_TRIGGER = 55


; ------------------------------------------------------
;                   PINES Y PUERTOS
; ------------------------------------------------------

; PORTB:
.equ ULTRASOUND_ECHO = 0
.equ SERVOA_PIN      = 1
.equ SERVOB_PIN      = 2
.equ ULTRASOUND_TRIG = 3
.equ ACTIVE_LED      = 4

; PORTD:
.equ BT_RX     = 0
.equ BT_TX     = 1
.equ INT0_PIN  = 2
.equ LASER_PIN = 3

;PORTC: 
.equ RESET_PIN = 6


; ------------------------------------------------------
;                 ESTADOS Y OBJETIVOS
; ------------------------------------------------------

; ESTADOS:
.equ IDLE      = 0x00
.equ MEDIR     = 0x01  ; A punto de medir (todavía no)
.equ MIDIENDO  = 0x02
.equ DELAY     = 0x03
.equ PROCESAR_COMANDO = 0x04
.equ WAIT_BYTE = 0x05
.equ PROCESAR_BYTE = 0x06

; OBJETIVOS:
.equ WAITING_COMMAND           = 0x00
.equ SCANNING                  = 0x01
.equ PRENDER_LASER             = 0x02
.equ APAGAR_LASER              = 0x03
.equ SINGLE_MEASURE            = 0x04
.equ WAITING_BYTES_MOVE_TO     = 0x05
.equ WAITING_BYTES_SCAN_REGION = 0x06


; ------------------------------------------------------
;                      COMUNICACIÓN
; ------------------------------------------------------

; COMANDOS:
.equ ABORT          = 'a'
.equ SCAN_ROW       = 's'
.equ SCAN_COL       = 't'
.equ SCAN_ALL       = 'z'
.equ SCAN_REGION    = 'w'
.equ MEDIR_DIST     = 'm'
.equ PING           = 'b'
.equ ASK_POSITION   = 'p'
.equ ASK_LASER      = 'l'
.equ TURN_ON_LASER  = 'c'
.equ TURN_OFF_LASER = 'd'
.equ MOVE_TO        = 'x'

; DATA TYPES:
.equ DONE             = 'f'
.equ MEASUREMENT      = 'm'
.equ CURRENT_POSITION = 'p'
.equ LASER_ON         = 'j'
.equ LASER_OFF        = 'k'
.equ PONG             = 'b'
.equ DEBUG            = 'o'
.equ BUSY             = 'n'
.equ WHAT             = 'w'


; ------------------------------------------------------
;                        REGISTROS
; ------------------------------------------------------

.def zero            = r0

.def first_stepa     = r4
.def first_stepb     = r5
.def last_stepa      = r6
.def last_stepb      = r7
.def bytes_restantes = r8
.def lectural        = r9
.def lecturah        = r10
.def min_distl       = r11
.def min_disth       = r12
.def min_stepa       = r13
.def min_stepb       = r14
.def tempbyte        = r15
.def temp            = r16
.def templ           = r17
.def temph           = r18
.def stepa           = r19
.def stepb           = r20
.def estado          = r21
.def objetivo        = r22
.def left_ovfs       = r23
.def data_type       = r24
.def byte_recibido   = r25



; ------------------------------------------------------
;                         MACROS
; ------------------------------------------------------

.macro ldx
	ldi XL, LOW(@0)
	ldi XH, HIGH(@0)
.endmacro

.macro ldy
	ldi YL, LOW(@0)
	ldi YH, HIGH(@0)
.endmacro

.macro ldz
	ldi ZL, LOW(@0)
	ldi ZH, HIGH(@0)
.endmacro

; ***** END OF FILE ******************************************************
