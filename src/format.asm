[ORG 0x100]

cmp [0x80], byte 0
jne display_warning

mov ah, 0x9
mov dx, parameter_incorrect_msg
int 0x21

jmp exit

display_warning:
    mov ah, 0x9
    mov dx, warning_msg
    int 0x21

    mov ah, 1
    int 0x21

    cmp al, 'y'
    jne exit

    mov dl, [0x82]
    cmp dl, 'a'
    jl .upper_case

    sub dl, 'c'
    add dl, 0x80
    mov [drive_number], dl

    jmp .read_geometry

.upper_case:
    sub dl, 'C'
    add dl, 0x80
    mov [drive_number], dl

.read_geometry:
    mov ah, 08h
    int 13h
    jc disk_error

    and cl, 0x3F
    xor ch, ch
    mov [sectors_per_track], cx
    mov [boot + 0x18], cx

    inc dh
    mov [heads], dh
    mov [boot + 0x1A], dh

    mov ah, 0x9
    mov dx, formatting_msg
    int 0x21

    xor ax, ax
    mov cl, 1
    mov bx, clear_sector

.clear_loop:
    call write_disk
    jc .clear_done
    add ax, 1
    jmp .clear_loop

.clear_done:
    mov [boot + 0x13], ax

    xor dx, dx
    mov cx, 4
    div cx
    xor dx, dx
    mov cx, 256
    div cx

    inc ax

    mov [boot + 0x16], ax
    mov ax, [sectors_per_track]
    mov [boot + 0x18], ax
    mov ax, [heads]
    mov [boot + 0x1A], ax
    
    xor ah, ah
    int 0x1A

    mov [boot + 0x27], cx
    mov [boot + 0x29], dx

    xor ax, ax
    mov cl, 1
    mov bx, boot
    call write_disk
    jc disk_error

    mov ax, [boot + 0xE]
    mov cl, 1
    mov bx, fat
    call write_disk
    jc disk_error

    mov ax, [boot + 0x16]
    add ax, [boot + 0xE]    
    mov cl, 1
    mov bx, fat
    call write_disk
    jc disk_error

    mov ah, 0x9
    mov dx, formatted_msg
    int 0x21
    mov dx, enter_vol_label_msg
    int 0x21

    xor bx, bx

.loop:
    mov ah, 1
    int 0x21

    cmp al, 0xD
    je .write_root

    mov [es:bx + root], al
    inc bx

    cmp bx, 11
    jge .write_root

    jmp .loop

.write_root:
    mov ax, [boot + 0x16]
    add ax, [boot + 0xE]
    add ax, [boot + 0x16]
    mov cl, 1
    mov bx, root
    call write_disk
    jc disk_error

    jmp exit

disk_error:
    mov ah, 0x9
    mov dx, disk_error_msg
    int 0x21

exit:
    mov ah, 0x9
    mov dx, newline
    int 0x21

    mov ax, 0x4C00
    int 0x21

lba_to_chs:
    push ax
    push dx
    
    xor dx, dx
    div word [cs:sectors_per_track]
    inc dx
    mov [cs:sector], dx
    xor dx, dx
    div word [cs:heads]
    mov [cs:cylinder], ax
    mov [cs:head], dx
    
    pop dx
    pop ax

    mov ch, [cs:cylinder]
    mov cl, [cs:sector]
    mov dh, [cs:head]

    ret

write_disk:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax
    mov dl, [drive_number]
    mov ah, 0x3

    int 0x13

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers
    ret

parameter_incorrect_msg: db 0xA, 0xD, "Incorrect parameter format", 0xA, 0xD, '$'
warning_msg: db 0xA, 0xD, "WARNING ! All data on the drive will be deleted!", 0xA, 0xD, "Continue formatting (y/n)? $"
disk_error_msg: db 0xA, 0xD, "An error occured while performing drive operations!", 0xA, 0xD, '$'
formatting_msg: db 0xA, 0xD, "Formatting... $"
formatted_msg: db "Disk Formatted$"
enter_vol_label_msg: db 0xA, 0xD, "Enter volume label (Enter for none): $"
newline: db 0xA, 0xD, '$'
drive_number: db 0

sectors_per_track:       dw 0x20
heads:                   dw 2

cylinder: dw 0
head: dw 0
sector: dw 0

fat:
    dw 0xFFF8
    dw 0xFFFF
    resb 508

clear_sector:
    resb 512

root:
    db "           "
    db 0b1000
    resb 500

boot:
    ; Will be added at compile time