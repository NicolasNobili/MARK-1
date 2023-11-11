;
; MARK1_servos.asm
;
; Created: 11/11/2023 14:43:08
; Authors: FR & NN
; 

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
    breq stepa_up_end

    inc stepb
    rcall actualizar_OCR1B

stepb_up_end:
    ret

; Decrementa STEPB si es posible
stepb_down:
    cpi stepb, 0
    breq stepa_down_end

    dec stepb
    rcall actualizar_OCR1B

stepb_up_down:
    ret


; Escribe en OCR1A = STEPA * STEP_OCR1A + MIN_OCR1A
actualizar_OCR1A:
    in temp, sreg
    push temp
    cli

    ldi temp, STEP_OCR1A
    mul stepa, temp

    ldi templ, LOW(MIN_OCR1A)
    ldi temph, HIGH(MIN_OCR1A)
    
    add templ, r0
    adc temph, r1

    sts OCR1AH, temph
    sts OCR1AL, templ

end_actualizar_OCR1A:
    pop temp
    out sreg, temp
    ret

; Escribe en OCR1B = STEPB * STEP_OCR1B + MIN_OCR1B
actualizar_OCR1B:
    in temp, sreg
    push temp
    cli

    ldi temp, STEP_OCR1B
    mul stepb, temp

    ldi templ, LOW(MIN_OCR1B)
    ldi temph, HIGH(MIN_OCR1B)
    
    add templ, r0
    adc temph, r1

    sts OCR1BH, temph
    sts OCR1BL, templ

end_actualizar_OCR1B:
    pop temp
    out sreg, temp
    ret
