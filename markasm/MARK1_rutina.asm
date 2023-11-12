;
; MARK1_rutina.asm
;
; Created: 11/11/2023 16:12:54
; Author: FR & NN
; 

start_timer0:
    ; Cuenta en 0
    clr temp
    out TCNT0, temp

    ; Prescaler 1024
    ldi temp, (1 << CS02) | (0 << CS01) | (1 << CS00)
    out TCCR0B, temp
    
    ret

stop_timer0:
    ; Apagado
    ldi temp, (0 << CS02) | (0 << CS01) | (0 << CS00)
    out TCCR0B, temp
    
    ret

start_timer2:
    ; Cuenta en 0
    clr temp
    sts TCNT2, temp

    ; Prescaler 1024
    ldi temp, (1 << CS22) | (0 << CS21) | (1 << CS20)
	sts TCCR2B, temp
    
    ret

stop_timer2:
    ; Apagado
    ldi temp, (0 << CS22) | (0 << CS21) | (0 << CS20)
    sts TCCR2B, temp
    
    ret

send_trigger:
	sbi PORTB,ULTRASOUND_TRIG
	ldi temp,60

loop_trig:
	dec temp
	brne loop_trig
	cbi PORTB,ULTRASOUND_TRIG

	ret

transmit_measure:
	ret

