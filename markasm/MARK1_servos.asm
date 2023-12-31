; ---------------------------------
; MARK1_servos.asm
;
; Created: 11/11/2023 14:43:08
; Authors: FR & NN
; ---------------------------------


; ------------------------------------------------------
;                  STEP UPS Y DOWNS
; ------------------------------------------------------

; Incrementa STEPA si es posible
stepa_up:
    cpi stepa, MAX_STEPA
    breq stepa_up_end

    inc stepa
    rcall actualizar_OCR1A

stepa_up_end:
    ret


; Decrementa STEPA si es posible
stepa_down:
    cpi stepa, 0
    breq stepa_down_end

    dec stepa
    rcall actualizar_OCR1A

stepa_down_end:
    ret


; Incrementa STEPB si es posible
stepb_up:
    cpi stepb, MAX_STEPB
    breq stepb_up_end

    inc stepb
    rcall actualizar_OCR1B

stepb_up_end:
    ret


; Decrementa STEPB si es posible
stepb_down:
    cpi stepb, 0
    breq stepb_down_end

    dec stepb
    rcall actualizar_OCR1B

stepb_down_end:
    ret


; ------------------------------------------------------
;                 MODIFICACIÓN DE OCR1X
; ------------------------------------------------------

; Las funciones step up, down lo hacen automáticamente
; Escribe en OCR1A = STEPA * STEP_OCR1A + MIN_OCR1A
actualizar_OCR1A:
	push r0
	push r1

    in temp, sreg
    push temp
    cli

    ; Multiplicación
    ldi temp, STEP_OCR1A
    mul stepa, temp

    ; Suma
    ldi xl, LOW(MIN_OCR1A)
    ldi xh, HIGH(MIN_OCR1A)
    add xl, r0
    adc xh, r1

    ; Guardado
    sts OCR1AH, xh
    sts OCR1AL, xl

    pop temp
    out sreg, temp

	pop r1
	pop r0
	 
    ret


; Las funciones step up, down lo hacen automáticamente
; Escribe en OCR1B = STEPB * STEP_OCR1B + MIN_OCR1B
actualizar_OCR1B:
	push r0
	push r1

    in temp, sreg
    push temp
    cli

    ldi temp, STEP_OCR1B
    mul stepb, temp

    ldi xl, LOW(MIN_OCR1B)
    ldi xh, HIGH(MIN_OCR1B)
    
    add xl, r0
    adc xh, r1

    sts OCR1BH, xh
    sts OCR1BL, xl

    pop temp
    out sreg, temp

	pop r1
	pop r0
    ret
