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
	ret

config_timer0:
	ret

config_timer1:
	ret