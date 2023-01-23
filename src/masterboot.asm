[ORG 0x7e00]
[BITS 16]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov si, 0x7c00
    mov di, start
    mov cx, 0x200
    rep movsb

    jmp 0:.relocated

.relocated:
    mov [drive_number], dl

    mov ah, 0x8
    int 0x13
    jc err
    and cl, 0x3F
    xor ch, ch
    mov [sectors_per_track], cx
    inc dh
    mov [heads], dh

    mov ax, [part_0 + 8]
    mov cl, 1
    mov bx, 0x7c00
    call read_disk

    mov dl, [drive_number]
    jmp 0x7c00

lba_to_chs:
    push ax
    push dx
    
    xor dx, dx
    div word [sectors_per_track]
    inc dx
    mov [sector], dx
    xor dx, dx
    div word [heads]
    mov [cylinder], ax
    mov [head], dx
    
    pop dx
    pop ax

    mov ch, [cylinder]
    mov cl, [sector]
    mov dh, [head]

    ret

read_disk:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax
    mov dl, [drive_number]
    mov ah, 0x2

    int 0x13
    jc err

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

err:
    mov ah, 0xE
    mov al, 'E'
    int 0x10

    jmp $

drive_number: db 0
sectors_per_track:       dw 0x20
heads:                   dw 2

cylinder: dw 0
head: dw 0
sector: dw 0

times 440-($-$$) db 0
dd 0x5F69AB5C           ; Disk Identifier
dw 0
part_0:
    db 0                ; Not bootable
    dw 0x2120           ; CHS to LBA adress 2048
    db 0
    db 4                ; FAT16
    dw 0x292A
    db 2                ; 16MiB size
    dd 0x0800           ; LBA representive of above values
    dd 0x8001

resb 48
dw 0xAA55