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
    clr zero
    ldi stepa, STEPA_INICIAL
    ldi stepb, STEPB_INICIAL
    ldi estado, IDLE
    ldi objetivo, WAITING_COMMAND

	; Stack pointer
	ldi temp, LOW(RAMEND)
	out spl, temp
	ldi temp, HIGH(RAMEND)
	out sph, temp
	
	rcall config_ports
	rcall config_timer0
	rcall config_timer1
	rcall config_USART
	rcall config_int0
    rcall config_pci0
	
	sei
    

; ------------------------------------------------------
;                  LOOP PRINCIPAL
; ------------------------------------------------------

main_loop:

    cpi estado, MEDIR
    breq iniciar_medicion
	
	rjmp main_loop

iniciar_medicion:
    ; Esperamos que el ECHO haga una interrupción
    ; Mientras tanto no hay que hacer nada
    ldi estado, MIDIENDO
    rcall send_trigger

    rjmp main_loop

end_main: rjmp end_main


; ------------------------------------------------------
;                 RUTINAS Y HANDLERS
; ------------------------------------------------------

.include "MARK1_config.asm"
.include "MARK1_handlers.asm"
.include "MARK1_servos.asm"
.include "MARK1_rutina.asm"
