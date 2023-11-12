;
; MARK1_include.asm
;
; Created: 11/11/2023 11:40:49 AM
; Authors: FR & NN
; 
 
; AUXILIARES:
.equ INT0_PIN = 2

.equ CLK_FREQUENCY = 16000000
.equ PWM_PERIOD_US = 20000
.equ PWM_MAX_TON_US = 2500
.equ PWM_MIN_TON_US = 500
.equ BAUD_RATE = 9600

; CONSTANTES:
.equ MAX_STEPA = 20  ; Hay MAX_STEPA estados más el 0 = MAX_STEPA + 1 estados
.equ MAX_STEPB = 20  ; Hay MAX_STEPB estados más el 0 = MAX_STEPB + 1 estados
.equ STEPA_INICIAL = 10
.equ STEPB_INICIAL = 10

.equ TOP_PWM   = int( (CLK_FREQUENCY/8) * PWM_PERIOD_US / (2 * 1000000) ) ; del datasheet

.equ MAX_OCR1A = int(TOP_PWM - TOP_PWM * PWM_MIN_TON_US / PWM_PERIOD_US)
.equ MIN_OCR1A = int(TOP_PWM - TOP_PWM * PWM_MAX_TON_US / PWM_PERIOD_US)
.equ STEP_OCR1A = (MAX_OCR1A - MIN_OCR1A) / MAX_STEPA

.equ MAX_OCR1B = int(TOP_PWM - TOP_PWM * PWM_MIN_TON_US / PWM_PERIOD_US) 
.equ MIN_OCR1B = int(TOP_PWM - TOP_PWM * PWM_MAX_TON_US / PWM_PERIOD_US)
.equ STEP_OCR1B = (MAX_OCR1B - MIN_OCR1B) / MAX_STEPB

.equ UBRR0 = int( CLK_FREQUENCY / (16 * BAUD_RATE) - 1 )

.equ DELAY_MOVIMIENTO = 20 ; Medido en overflows del timer 0 (16 ms)
.equ DELAY_STEP = 10
; .equ DELAY_MEDICION = 2  ; Si hay echo siempre no debería ser necesario

; PUERTOS:
; PORTB:
.equ SERVO_PIN = 1
.equ ULTRASOUND_ECHO = 0
.equ ULTRASOUND_TRIG = 3
; PORTD:
.equ BT_RX = 0
.equ BT_TX = 1
.equ LASER_PIN = 2

; ESTADOS:
.equ IDLE = 0x00
.equ MEDIR = 0x01  ; A punto de medir (todavía no)
.equ MIDIENDO = 0x02
.equ DELAY = 0x03

; OBJETIVOS:
.equ WAITING_COMMAND = 0x00
.equ SCANNING_ROW = 0x01
.equ PRENDER_LASER = 0x02
.equ APAGAR_LASER = 0x03
.equ SINGLE_MEASURE = 0x04

; COMANDOS:
.equ ABORT = 'a'
.equ SCAN_ROW = 's'
.equ MEDIR_DIST = 'm'

; REGISTROS:
.def zero = r3
.def min_stepa = r12
.def min_stepb = r13
.def min_dist = r14
.def count_ovfs = r15
.def temp = r16
.def templ = r17
.def temph = r18
.def stepa = r19
.def stepb = r20
.def estado = r21
.def objetivo = r22
.def left_ovfs = r23


; MACROS:
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
