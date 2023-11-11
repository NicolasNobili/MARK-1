/*
 * MARK1_include.asm
 *
 *  Created: 11/11/2023 11:40:49 AM
 *   Author: FR & NN
 */ 
 

;CONSTANTES:

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