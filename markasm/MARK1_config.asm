/*
 * MARK1_config.asm
 *
 *  Created: 11/11/2023 11:49:48 AM
 *   Author: nnobi
 */ 

config_ports:
	;PORTB
	sbi DDRB,SERVO_PIN
	sbi DDRB,ULTRASOUND_TRIG
	cbi DDRB,ULTRASOUND_ECHO

	;PORTD
	sbi DDRD,LASER_PIN
	ret



config_USART:
	ldi temp,0b1001_0000
	sts UCSR0B,temp ; RX Complete Interrupt Enable  & Enable Receiver

	ldi temp,0b0000_0110 
	sts UCSR0C,temp ;8-bit data, no-parity, 1 stop  bit

	ldi temp,LOW(UBRR0) ; baud rate 9600
	sts UBRR0L,temp
	ldi temp,HIGH(UBRRO)
	sts UBRR0,temp

	ret



config_timer1:
	clr temp

	sts TCNT1H,temp
	sts TCNT1L,temp

	ldi temp,HIGH(TOP_PWM)
	sts ICR1H , temp
	ldi temp,LOW(TOP_PWM)
	sts ICR1L , temp

	ldi temp , HIGH(MAX_OCR1A)
	sts OCR1AH ,temp
	ldi temp , LOW(MAX_OCR1A) ; = 24000 (empieza con duty cicle de 0.5ms/25ms)
	sts OCR1Al,temp

	ldi temp , HIGH(MAX_OCR1B)
	sts OCR1BH ,temp
	ldi temp , LOW(MAX_OCR1B) ; = 24000 (empieza con duty cicle de 0.5ms/25ms)
	sts OCR1Bl,temp


	ldi temp , 0b1111_0010 ; "Set OC1A/OC1B on compare match when up-counting. Clear OC1A/OC1B on compare match when down-counting."
	sts TCCR1A,temp 
	ldi temp , 0b001_0010
	sts TCCR1B, temp ;-> Phase-correct PWM (top = ICR1) mode con prescale = 1/8

	ret

config_timer0:
	clr temp

	out TCCR0A,temp
	out TCCR0B,temp ;-> Normal mode y apagado

	;Activo Interrupcion por overflow 
	ldi temp,0x01
	sts TIMSK0,temp

	ret