/*
 * MARK1_include.asm
 *
 *  Created: 11/11/2023 11:40:49 AM
 *   Author: FR & NN
 */ 
 

;CONSTANTES:

.equ TOP_PWM = int( (16000000/8) * 0.02 /2 ); 20000 perido de 20ms (prescaler  = 8)
.equ MAX_OCR1A = int(TOP_PWM - TOP_PWM * 0.0005 /0.020)  ; 19500 (ancho pulso = 0.5ms)
.equ MIN_OCR1A =int(TOP_PWM - TOP_PWM * 0.0025 /0.020) ; 17500 (ancho pulso = 2.5ms)
.equ MAX_OCR1B = int(TOP_PWM - TOP_PWM * 0.0005 /0.020)  ; 19500 (ancho pulso = 0.5ms)
.equ MIN_OCR1B =int(TOP_PWM - TOP_PWM * 0.0025 /0.020) ; 17500 (ancho pulso = 2.5ms)

.equ UBRR0 = 103

;-Puertos:
;PORTB:
.equ SERVO_PIN = 1
.equ ULTRASOUND_ECHO = 0
.equ ULTRASOUND_TRIG = 2

;PORTD:
.equ BT_RX = 0
.equ BT_TX = 1
.equ LASER_PIN = 2

;-Estados:


;DEFINICIONES:
.def temp = r16

;MACROS:
.macro ldx
	ldi XL,LOW(@0)
	ldi XH,HIGH(@0)
.endmacro

.macro ldy
	ldi YL,LOW(@0)
	ldi YH,HIGH(@0)
.endmacro

.macro ldz
	ldi ZL,LOW(@0)
	ldi ZH,HIGH(@0)
.endmacro