; ---------------------------------
; Trabajo_Integrador.asm
;
; Created: 11/11/2023 10:50:07 AM
; Authors: FR & NN
; ---------------------------------

.include "MARK1_include.asm"


; ------------------------------------------------------
;                   MEMORIA DE DATOS
; ------------------------------------------------------

.dseg
.org SRAM_START


; ------------------------------------------------------
;                VECTOR DE INTERRUPCIONES
; ------------------------------------------------------

.cseg
.org 0x0000
    rjmp main
.org INT0addr
    rjmp handler_INT0
.org PCI0addr
	rjmp handler_PCIO
.org URXCaddr
    rjmp handler_URXC
.org OVF0addr
    rjmp handler_OVF0
.org OVF2addr
    rjmp handler_OVF2


; ------------------------------------------------------
;                  INICIALIZACIÓN
; ------------------------------------------------------

.org INT_VECTORS_SIZE
main:
	; Stack pointer
	ldi temp, LOW(RAMEND)
	out spl, temp
	ldi temp, HIGH(RAMEND)
	out sph, temp
	
	clr zero
    ldi stepa, STEPA_INICIAL
    ldi stepb, STEPB_INICIAL
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND

	rcall config_ports
	rcall config_timer0
	rcall config_timer1
	rcall config_USART
	rcall config_int0
    rcall config_pci0

	ldi data_type,CURRENT_POSITION
	rcall send_data
	
	sbis PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    sbic PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data
		
	sei
    

; ------------------------------------------------------
;                  LOOP PRINCIPAL
; ------------------------------------------------------

main_loop:
	
	cpi estado, IDLE
	breq main_sleep

    cpi estado, MEDIR
    breq main_iniciar_medicion

    cpi estado, PROCESAR_BYTE
    breq main_procesar_byte

    cpi estado, PROCESAR_COMANDO
    breq main_procesar_comando
	
	rjmp main_loop


; ------------------------------------------------------
;						SLEEP
; ------------------------------------------------------

main_sleep:
	cpi objetivo,WAITING_COMMAND
	brne main_loop

	ldi temp, (1 << SM1) | (1 << SM0) | (1 << SE); Modo Power-Save. Mantine prendida la USART para despertarse
    out MCUCR, temp 
	sleep
	out MCUCR,zero

	rjmp main_loop

; ------------------------------------------------------
;                  INICIAR MEDICION
; ------------------------------------------------------

main_iniciar_medicion:
    ; Esperamos que el ECHO haga una interrupción
    ; Mientras tanto no hay que hacer nada
    ldi estado, MIDIENDO
    rcall send_trigger

    rjmp main_loop

main_procesar_byte:
    ; Vemos para qué queríamos este byte
    cpi objetivo, WAITING_BYTES_MOVE_TO
    breq comando_byte_move_to

    cpi objetivo, WAITING_BYTES_SCAN_REGION
    breq comando_byte_scan_region

    ; No deberíamos llegar acá
    rjmp main_loop

comando_byte_move_to:
    ; Vemos a qué corresponde este byte
    mov temp, bytes_restantes

    cpi temp, 2
    breq comando_byte_stepa

    cpi temp, 1
    breq comando_byte_stepb

    ; No deberíamos llegar acá
    rjmp main_loop

comando_byte_stepa:
    ; Todavía falta stepb...
    mov stepa, byte_recibido
    dec bytes_restantes
    ldi estado, WAIT_BYTE

    rjmp main_loop

comando_byte_stepb:
    ; Ya tenemos todos los datos! Podemos proceder
    mov stepb, byte_recibido

    ; Mover
    rcall actualizar_OCR1A
    rcall actualizar_OCR1B

    ; Notificar el cambio
    ldi data_type, CURRENT_POSITION
    rcall send_data

    ; Hacer un delay por overflows para
    ; dar tiempo al movimiento
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado, DELAY
    rcall start_timer0

    ; Luego del delay de movimiento no queremos hacer nada
    ldi objetivo, WAITING_COMMAND

    rjmp main_loop

comando_byte_scan_region:
    ; HACER
    rjmp main_loop


; ------------------------------------------------------
;                 PROCESAR COMANDO
; ------------------------------------------------------

main_procesar_comando:
    ; La lectura de los siguientes comandos no modifican el estado
    ; (a excepción de ABORT) y se pueden realizar siempre

    cpi byte_recibido, ABORT
    breq comando_abort

    cpi byte_recibido, PING
    breq comando_ping

    cpi byte_recibido, ASK_POSITION
    breq comando_ask_position

    cpi byte_recibido, ASK_LASER
    breq comando_ask_laser

    ; Para otros comandos, primero verificamos si estamos en WAITING_COMMAND
    ; Si no, devolvemos que estamos ocupados
    cpi objetivo, WAITING_COMMAND
    brne send_busy

    ; Leer comando

    cpi byte_recibido, SCAN_ROW
    breq comando_scan_row

    cpi byte_recibido, MOVE_TO
    breq comando_move_to

    cpi byte_recibido, MEDIR_DIST
    breq comando_medir_dist

    cpi byte_recibido, TURN_ON_LASER
    breq comando_turn_on_laser

    cpi byte_recibido, TURN_OFF_LASER
    breq comando_turn_off_laser

    ; Comando desconocido
    ldi data_type, WHAT
    rcall send_data
	ldi estado,IDLE
    rjmp main_loop

comando_abort:
    ; Nos quedamos donde estamos
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND

    rjmp main_loop

comando_ping:
    ; Ping - pong
    ldi data_type, PONG
    rcall send_data
	ldi estado,IDLE

    rjmp main_loop

comando_ask_position:
    ; Devolvemos la posición
    ldi data_type, CURRENT_POSITION
    rcall send_data
	ldi estado,IDLE

    rjmp main_loop

comando_ask_laser:
    ; Devolvemos el estado actual del láser
    sbis PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    sbic PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data
	ldi estado,IDLE

    rjmp main_loop

send_busy:
    ldi data_type, BUSY
    rcall send_data
	ldi estado,IDLE

    rjmp main_loop

comando_scan_row:
    ; Mover el servo A al mínimo
    ldi stepa, 0
    rcall actualizar_OCR1A

    ; Notificar del cambio de posición
    ldi data_type, CURRENT_POSITION
    rcall send_data

    ; Hacer un delay por overflows para
    ; dar tiempo al movimiento
    ldi left_ovfs, DELAY_MOVIMIENTO
    ldi estado, DELAY
    rcall start_timer0

    ; Setear la distancia mínima en 0xFF
	clr min_dist
	dec min_dist

    ; Actualizar objetivo
    ldi objetivo, SCANNING_ROW

	rjmp main_loop

comando_move_to:
    ; Necesitamos 2 bytes más (stepa, stepb)
    clr bytes_restantes
    inc bytes_restantes
    inc bytes_restantes
    ldi estado, WAIT_BYTE
    ldi OBJETIVO, WAITING_BYTES_MOVE_TO

    rjmp main_loop

comando_medir_dist:
    ; Queremos medir solo una vez
	ldi estado, MEDIR
	ldi objetivo, SINGLE_MEASURE

    rjmp main_loop

comando_turn_on_laser:
	; Encender láser y notificar cambio de estado
	sbi PORTD, LASER_PIN
    ldi data_type, LASER_ON
    rcall send_data
	ldi estado,IDLE

    rjmp main_loop

comando_turn_off_laser:
	; Apagar láser y notificar cambio de estado
	cbi PORTD, LASER_PIN
    ldi data_type, LASER_OFF
    rcall send_data
	ldi estado,IDLE

    rjmp main_loop

end_main:
    rjmp end_main


; ------------------------------------------------------
;                 RUTINAS Y HANDLERS
; ------------------------------------------------------

.include "MARK1_config.asm"
.include "MARK1_handlers.asm"
.include "MARK1_servos.asm"
.include "MARK1_rutina.asm"
