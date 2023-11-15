; ---------------------------------
; Trabajo_Integrador.asm
;
; Created: 11/11/2023 10:50:07 AM
; Authors: FR & NN
; ---------------------------------

.include "MARK1_include.asm"


; ------------------------------------------------------
;                    MEMORIA EEPROM
; ------------------------------------------------------
.eseg
.org INFO_ADDR

default_info:
    .db "Connected to MARK1: Multi Angle Radar Kinematics Mk.1", 0


; ------------------------------------------------------
;                   MEMORIA DE DATOS
; ------------------------------------------------------

.dseg
.org SRAM_START

buffer: .byte MAX_STRING


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
;                  INICIALIZACION
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
	rcall config_timer2
	rcall config_USART
	rcall config_int0
    rcall config_pci0

	sbi PORTB, ACTIVE_LED

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
	cpi objetivo, WAITING_COMMAND
	brne main_loop
    cbi PORTB, ACTIVE_LED

    ; Modo Idle. Mantiene prendida la USART para despertarse
	ldi temp, (0 << SM2) | (0 << SM1) | (0 << SM0) | (1 << SE)
    out SMCR, temp 
	sleep
	out SMCR, zero

    sbi PORTB, ACTIVE_LED
	rjmp main_loop


; ------------------------------------------------------
;                  INICIAR MEDICION
; ------------------------------------------------------

main_iniciar_medicion:
    ; Esperamos que el ECHO haga una interrupci�n
    ; Mientras tanto no hay que hacer nada
    ldi estado, MIDIENDO
    rcall send_trigger

    rjmp main_loop


; ------------------------------------------------------
;                  PROCESAR BYTE
; ------------------------------------------------------

main_procesar_byte:
    ; Vemos para qu� quer�amos este byte
    cpi objetivo, WAITING_BYTES_MOVE_TO
    breq comando_byte_move_to

    cpi objetivo, WAITING_BYTES_SCAN_REGION
    breq comando_byte_scan_region

    cpi objetivo, WAITING_BYTES_WRITE_INFO
    breq comando_byte_write_info

    ; No deber�amos llegar ac�
    rjmp main_loop

comando_byte_move_to:
    rcall rutina_comando_byte_move_to
    rjmp main_loop

comando_byte_scan_region:
    rcall rutina_comando_byte_scan_region
    rjmp main_loop

comando_byte_write_info:
    rcall rutina_comando_byte_write_info
    rjmp main_loop


; ------------------------------------------------------
;                 PROCESAR COMANDO
; ------------------------------------------------------

main_procesar_comando:
    ; La lectura de los siguientes comandos no modifican el estado
    ; (a excepci�n de ABORT) y se pueden realizar siempre

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

	cpi byte_recibido, SCAN_COL
    breq comando_scan_col

	cpi byte_recibido, SCAN_ALL
    breq comando_scan_all

	cpi byte_recibido, SCAN_REGION
    breq comando_scan_region

    cpi byte_recibido, MOVE_TO
    breq comando_move_to

    cpi byte_recibido, MEDIR_DIST
    breq comando_medir_dist

    cpi byte_recibido, TURN_ON_LASER
    breq comando_turn_on_laser

    cpi byte_recibido, TURN_OFF_LASER
    breq comando_turn_off_laser

    cpi byte_recibido, WRITE_INFO
    breq comando_write_info

    ; Comando desconocido
    ldi data_type, WHAT
    rcall send_data
	ldi estado,IDLE
    rjmp main_loop


send_busy:

    ldi data_type, BUSY
    rcall send_data
	ldi estado,IDLE

    rjmp main_loop

comando_abort:
    rcall rutina_comando_abort
    rjmp main_loop

comando_ping:
	rcall rutina_comando_ping
    rjmp main_loop

comando_ask_position:
	rcall rutina_comando_ask_position
    rjmp main_loop

comando_ask_laser:
	rcall rutina_comando_ask_laser
    rjmp main_loop

comando_scan_row:
	rcall rutina_comando_scan_row
	rjmp main_loop

comando_scan_col:
	rcall rutina_comando_scan_col
	rjmp main_loop

comando_scan_all:
	rcall rutina_comando_scan_all
	rjmp main_loop

comando_scan_region:
	rcall rutina_comando_scan_region
	rjmp main_loop

comando_move_to:
	rcall rutina_comando_move_to
    rjmp main_loop

comando_medir_dist:
	rcall rutina_comando_medir_dist
    rjmp main_loop

comando_turn_on_laser:
	rcall rutina_comando_turn_on_laser
    rjmp main_loop

comando_turn_off_laser:
	rcall rutina_comando_turn_off_laser
    rjmp main_loop

comando_write_info:
    rcall rutina_comando_write_info
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
