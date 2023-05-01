[ORG 0x100]

mov ah, 0x25
mov al, 0x29
mov dx, int_29h
int 0x21

mov ah, 0x9
mov dx, installed_msg
int 0x21

mov ax, 0x3100
mov dx, end
shr dx, 4
int 0x21

int_29h:
    pusha
    push es

    cmp [cs:sequence], byte 1
    je .sequence

    cmp al, 0x1b
    jne .continue

    mov [cs:sequence], byte 1
    jmp .done

.sequence:
    cmp al, 0xD
    je .handle_sequence

    xor bh, bh
    mov bl, [cs:sequence_buffer_offset]
    mov [cs:bx + sequence_buffer], al
    inc byte [cs:sequence_buffer_offset]
    jmp .done

.handle_sequence:
    mov [cs:sequence], byte 0
    mov [cs:sequence_buffer_offset], byte 0

    mov bx, sequence_buffer
    cmp [cs:bx], byte 0x5B
    jne .done

    xor dx, dx
    mov cx, 10
    xor ax, ax

.loop:
    inc bx
    cmp [cs:bx], byte 0
    je .done

    mov dl, [cs:bx]
    sub dl, '0'
    
    add ax, dx

    cmp [cs:bx + 1], byte 'm'
    je .execute_sequence
    cmp [cs:bx + 1], byte 0
    je .done

    mul cx

    jmp .loop

.execute_sequence:
    cmp ax, 0
    je .reset_color

    mov bx, ax
    mov dl, [cs:bx + color_and_table]
    and [cs:color], dl
    mov dl, [cs:bx + color_or_table]
    or [cs:color], dl

    jmp .done

.reset_color:
    mov [cs:color], byte 0x7
    jmp .done

.continue:
    push ax

    mov ah, 0xF
    int 0x10

    push ax

    xor bh, bh
    mov ah, 0x3
    int 0x10

    pop ax

    shr ax, 8

    mov cx, dx

    shr dx, 8
    mul dx
    xor ch, ch
    add ax, cx
    mov cx, 2
    mul cx

    mov bx, 0xb800
    mov es, bx
    mov bx, 0x000
    add bx, ax
    inc bx
    mov al, [cs:color]
    mov [es:bx], al

    pop ax
    mov ah, 0xE
    int 0x10

.done:
    pop es
    popa
    iret

installed_msg: db 0xA, 0xD, "DaviDOS ANSI driver v1.0 installed.", 0xA, 0xD, '$'

color_and_table:
    resb 30
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    resb 2
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    resb 42
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    db 0xF0
    resb 2
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    db 0xF
    db 0xF

color_or_table:
    resb 30
    db 0
    db 0x4
    db 0x2
    db 0xE
    db 0x1
    db 0x5
    db 0x3
    db 0x7
    resb 2
    db 0
    db 0x40
    db 0x20
    db 0xE0
    db 0x10
    db 0x50
    db 0x30
    db 0x70
    resb 42
    db 0x8
    db 0xC
    db 0xA
    db 0xE
    db 0x9
    db 0xD
    db 0xB
    db 0xF
    resb 2
    db 0x80
    db 0xC0
    db 0xA0
    db 0xE0
    db 0x90
    db 0xD0
    db 0xB0
    db 0xF0


color: db 0x7
sequence: db 0
sequence_buffer_offset: db 0
sequence_buffer: resb 16

end: