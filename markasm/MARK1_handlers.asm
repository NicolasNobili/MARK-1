; ---------------------------------
; MARK1_handlers.asm
;
; Created: 11/11/2023 11:54:04 AM
; Authors: FR & NN
; ---------------------------------


; ------------------------------------------------------
;                   OVERFLOW TIMER 0
; ------------------------------------------------------

handler_OVF0:
    in temp, sreg
    push temp

    ; Verificar si debemos seguir esperando
    dec left_ovfs
    brne handler_OVF0_end

    ; Una vez que ya no hay m�s espera, apagar
    ; timer 0 y ver qu� sigue hacer
    rcall stop_timer0

    cpi objetivo, SCANNING_ROW
    breq objetivo_scanning_row

	cpi objetivo, PRENDER_LASER
    breq objetivo_prender_laser

	cpi objetivo, APAGAR_LASER
    breq objetivo_apagar_laser

    ; Otro objetivo
    cpi estado, IDLE
    rjmp handler_OVF0_end

objetivo_scanning_row:
    rcall stop_timer0

    ; Solicitamos una medici�n (al main loop)
    ldi estado, MEDIR

    rjmp handler_OVF0_end

objetivo_prender_laser:
    ; Es necesario?
	rcall stop_timer0

    ; Encender l�ser y notificar cambio de estado
	sbi PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data

    ; Dar un tiempo para mantener el laser prendido
	ldi estado, DELAY
	ldi objetivo, APAGAR_LASER
	ldi left_ovfs, DELAY_LASER
	rcall start_timer0

	rjmp handler_OVF0_end

objetivo_apagar_laser:
    ; Se termin� la fiesta
	cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data
	ldi data_type, DONE
	rcall send_data

	rcall stop_timer0
	ldi estado, IDLE
	ldi objetivo, WAITING_COMMAND

	rjmp handler_OVF0_end

handler_OVF0_end:
    pop temp
    out sreg, temp
    reti


; ------------------------------------------------------
;                   OVERFLOW TIMER 2
; ------------------------------------------------------

handler_OVF2:
	in temp,sreg
	push temp
	
	inc count_ovfs

handler_OVF2_end:
	pop temp
	out sreg,temp
	reti


; ------------------------------------------------------
;                  COMUNICACI�N SERIAL
; ------------------------------------------------------

; Recepci�n de comandos
handler_URXC:
    in temp, sreg
    push temp

    ; Leer caracter
    lds byte_recibido, UDR0

    ; Ver si esto es un byte extra de un comando
    cpi estado, WAIT_BYTE
    breq byte_extra_recibido

    ; Interpretamos como un comando o inicio de comando en s�
    ldi estado, PROCESAR_COMANDO
    rjmp handler_URXC_end

byte_extra_recibido:
    ldi estado, PROCESAR_BYTE
    rjmp handler_URXC_end

handler_URXC_end:
    pop temp
    out sreg, temp
    reti


; ------------------------------------------------------
;           INTERRUPCI�N INT0 PARA DEBUGEAR
; ------------------------------------------------------

handler_INT0:
    in temp, sreg
    push temp

    ; Falta implementar la medici�n de tiempo

    ; Mandar informaci�n por USART (stepa, stepb, medicion)

    cpi stepa, MAX_STEPA
    breq terminar_objetivo_aux_aux

    rcall stepa_up
    ldi estado, DELAY
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0

    rjmp handler_INT0_end

terminar_objetivo_aux_aux:
	ldi stepa,STEPA_INICIAL
	rcall actualizar_OCR1A
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND

handler_INT0_end:
    pop temp
    out sreg, temp
    reti


; ------------------------------------------------------
;           INTERRUPCI�N PIN CHANGE 0 (ECHO)
; ------------------------------------------------------

handler_PCIO:
	in temp,sreg
	push temp

    ; Determinar en qu� flanco estamos
	sbic PINB, ULTRASOUND_ECHO
	rjmp start_measure

process_measure:
    ; Flanco descendiente, termina la lectura
	rcall stop_timer2

	;Desactivar interrupcion PCI0
	lds temp,PCICR
	andi temp,~(1<<PCIE0)
	sts PCICR,temp

    ; Convertir la lectura a 1 byte
	ldi data_type,DEBUG
	rcall send_data

	lds temp, TCNT2
	lsr count_ovfs
	ror temp
	mov lectura, temp
	
    ; Comparar con m�nimo
	cp lectura, min_dist
	brsh send_measure

    ; Reemplazar m�nimo
	mov min_dist, lectura
	mov min_stepa, stepa
	mov min_stepb, stepb

send_measure:
    ; Mandar info al serial
    ldi data_type, MEASUREMENT
	rcall send_data

    ; C�mo seguimos depende del objetivo actual

	cpi objetivo, SINGLE_MEASURE
	breq terminar_single_measure
    
    cpi objetivo, SCANNING_ROW
    breq continuar_scanning_row

    ; No deber�a llegar ac�
    rjmp handler_PCI0_end

continuar_scanning_row:
    ; Vemos si podemos seguir avanzando
    cpi stepa, MAX_STEPA
    breq terminar_scanning_row

    ; Podemos seguir, dar tiempo
    ; para moverse a la siguiente posici�n
    rcall stepa_up
    ldi estado, DELAY
    ldi left_ovfs, DELAY_STEP
    rcall start_timer0
	
	ldi data_type, CURRENT_POSITION
	rcall send_data

    rjmp handler_PCI0_end

terminar_scanning_row:
    ; No podemos seguir avanzando, vamos
    ; a apuntar al m�nimo que encontramos
    mov stepa, min_stepa
    rcall actualizar_OCR1A
    mov stepb, min_stepb
    rcall actualizar_OCR1B
    
    ; Enviamos el cambio de posici�n
    ldi data_type, CURRENT_POSITION
    rcall send_data
    
    ; Ahora queremos prenderle un laser,
    ; despu�s de habernos movido ah�
    ldi objetivo, PRENDER_LASER
    ldi estado, DELAY
    ldi left_ovfs, DELAY_MOVIMIENTO
    rcall start_timer0

    rjmp handler_PCI0_end

terminar_single_measure:
    ; Nos quedamos donde estamos y listo
	ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND
	rjmp handler_PCI0_end

start_measure:
    ; Flanco ascendente, reci�n comienza la lectura
    ; Iniciar el timer 2 (m�s el bit extra por overflows)
	clr count_ovfs
	rcall start_timer2
    rjmp handler_PCI0_end

handler_PCI0_end:
	pop temp
	out sreg,temp
	reti
