;
; MARK1_config.asm
;
; Created: 11/11/2023 11:49:48 AM
; Authors: FR & NN
;

config_ports:
	; PORTB
	sbi DDRB, SERVO_PIN
	sbi DDRB, ULTRASOUND_TRIG
	cbi DDRB, ULTRASOUND_ECHO

	; PORTD
	sbi DDRD, LASER_PIN
    cbi DDRD, INT0_PIN
    sbi PORTD, INT0_PIN
	ret


config_extint:
    ; Flanco negativo
    ldi temp, (1 << ISC01) | (0 << ISC00)
    sts EICRA, temp 

    ; Habilitar interrupción
	sbi EIMSK, INT0

    ret


config_USART:
    ; TX & RX Complete Interrupt Enable, Enable TX & RX
	ldi temp, (1 << RXCIE0) | (1 << TXCIE0) | (1 << RXEN0) | (1 << TXEN0)
	sts UCSR0B, temp

    ;               Asynchronous USART                   no-parity                     8-bit data              1 stop bit
	ldi temp, (0 << UMSEL01) | (0 << UMSEL00) | (0 << UPM01) | (0 << UPM00) | (1 << UCSZ01) | (1 << UCSZ00) | (0 << USBS0)
	sts UCSR0C, temp

    ; Baud rate
	ldi temp, LOW(UBRR0)
	sts UBRR0L, temp
	ldi temp, HIGH(UBRR0)
	sts UBRR0H, temp

	ret



config_timer1:
	clr temp

    ; Reiniciar cuenta del timer
	sts TCNT1H, temp
	sts TCNT1L, temp

    ; Configurar la frecuencia del PWM
	ldi temp, HIGH(TOP_PWM)
	sts ICR1H, temp
	ldi temp, LOW(TOP_PWM)
	sts ICR1L, temp

    ; Valores iniciales PWM
    rcall actualizar_OCR1A
    rcall actualizar_OCR1B

    ; Set OC1A/OC1B on compare match when up-counting.
    ; Clear OC1A/OC1B on compare match when down-counting.
    ; Phase Correct PWM, top en ICR1
	ldi temp, (1 << COM1A1) | (1 << COM1A0) | (1 << COM1B1) | (1 << COM1B0) | (1 << WGM11) | (0 << WGM10)
	sts TCCR1A, temp 

    ; Phase Correct PWM, top en ICR1, prescaler 1/8
	ldi temp, (1 << WGM13) | (0 << WGM12) | (0 << CS12) | (1 << CS11) | (0 << CS10)
	sts TCCR1B, temp

	ret

config_timer0:
	clr temp

    ; Modo normal apagado
	out TCCR0A, temp
	out TCCR0B, temp

	; Interrupción por overflow
	ldi temp, (1 << TOIE0)
	sts TIMSK0, temp

	ret
