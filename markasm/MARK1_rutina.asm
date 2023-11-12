; ---------------------------------
; MARK1_rutina.asm
;
; Created: 11/11/2023 16:12:54
; Author: FR & NN
; ---------------------------------


; ------------------------------------------------------
;                       TIMER 0
; ------------------------------------------------------

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


; ------------------------------------------------------
;                       TIMER 2
; ------------------------------------------------------

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

; ------------------------------------------------------
;                       TRIGGER
; ------------------------------------------------------

send_trigger:
	;Limpiar flag de PCI0 y activar la interrupcion
	sbi PCIFR,PCIF0
	 
	lds temp,PCICR
	ori temp,(1 << PCIE0)
	sts PCICR,temp
	
	sbi PORTB, ULTRASOUND_TRIG
	ldi temp, LOOPS_TRIGGER
loop_trig:
	dec temp
	brne loop_trig
	cbi PORTB, ULTRASOUND_TRIG

	ret


; ------------------------------------------------------
;                COMUNICACIÓN SERIAL
; ------------------------------------------------------

; Se debe cargar previamente el registro data_type
send_data:
    ; Mandar primero el byte de tipo de dato
    mov tempbyte, data_type
    rcall send_byte

    ; Ver si hay que mandar bytes extra, según el tipo de dato

    cpi data_type, MEASUREMENT
    breq send_measurement

    cpi data_type, CURRENT_POSITION
    breq send_position

	cpi data_type, DEBUG
	breq send_debug

    ; No hace falta mandar bytes extra
    rjmp send_data_end

send_measurement:
    ; Formato: A, B, lectura
    mov tempbyte, stepa
    rcall send_byte
    mov tempbyte, stepb
    rcall send_byte
    mov tempbyte, lectura
    rcall send_byte

    rjmp send_data_end

send_position:
    ; Formato: A, B
    mov tempbyte, stepa
    rcall send_byte
    mov tempbyte, stepb
    rcall send_byte

    rjmp send_data_end

send_debug:
	mov tempbyte, count_ovfs
    rcall send_byte

	rjmp send_data_end

send_data_end:
    ret


; Se debe cargar previamente el registro tempbyte
send_byte:
    lds temp, UCSR0A
    sbrs temp, UDRE0
    rjmp send_byte

    sts UDR0, tempbyte
    ret

