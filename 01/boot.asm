ORG 0x7C00
BITS 16

; https://www.ctyme.com/intr/rb-0106.htm
; Int 10/AH=0Eh - VIDEO - TELETYPE OUTPUT
;
; AH = 0Eh
; AL = character to write
; BH = page number
; BL = foreground color (graphics modes only)
;
; Return:
; Nothing
start:
    mov ah, 0Eh
    mov al, 'A'
    mov bx, 0
    int 0x10

    jmp $

times 510-($ - $$) db 0
dw 0xAA55
