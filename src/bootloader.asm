[ORG 0x7c00]
[BITS 16]

jmp short start
nop

; Bios Parameter Block
oem_name                db "MSWIN4.1"
bytes_per_sector        dw 0x200
sectors_per_cluster     db 0x4
reserved_sectors        dw 0x4
fat_copies              db 2
total_dir_entries       dw 0x200
total_sectors           dw 0x8000
media_descriptor        db 0xF8
sectors_per_fat         dw 0x20
sectors_per_track       dw 0x20
heads                   dw 2
hidden_sectors          dd 0
                        dd 0

; Extended Bios Parameter Block
drive_number            db 0x0
dirty                   db 0
boot_signature          db 0x29
serial_number           db 0x63, 0x58, 0x44, 0x77
label                   db "NO NAME    "
file_system             db "FAT16   "

start:
    ; Setup segment and stack registers
    cmp cx, 0xFFFF
    jne .no_part

    mov [part_lba], bx

.no_part:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov [drive_number], dl

    push es
    mov ah, 0x8
    int 0x13
    pop es

    and cl, 0x3F
    xor ch, ch
    mov [sectors_per_track], cx

    inc dh
    mov [heads], dh

    xor bx, bx

    mov ax, [sectors_per_fat]
    mov bl, [fat_copies]
    mul bx
    add ax, [reserved_sectors]
    push ax

    xor ax, ax
    xor bx, bx

    mov ax, [total_dir_entries]
    mov bl, 32
    mul bx

    div word [bytes_per_sector]

    mov cl, al
    mov [cs:root_size], cl
    pop ax

    mov bx, buffer

    call read_disk

    mov di, buffer
    xor bx, bx

.search_kernel:
    mov cx, 11
    mov si, kernel
    push di
    repe cmpsb
    pop di
    je .found_kernel
    add di, 32
    inc bx
    cmp bx, [total_dir_entries]
    jl .search_kernel

    mov si, non_system_msg
    call print_string
    
    xor ah, ah
    int 0x16

    jmp 0xFFFF:0

.found_kernel:
    mov ax, [di + 26]           ; First cluster field
    mov [kernel_cluster], ax
    
    mov ax, [reserved_sectors]
    mov cl, [sectors_per_fat]
    mov bx, buffer

    call read_disk

    mov bx, 0x500

    mov ax, [cs:sectors_per_fat]
    mul byte [cs:fat_copies]
    add ax, [cs:reserved_sectors]
    add al, [cs:root_size]
    mov [cs:start_sector], ax

.load_kernel_loop:
    ; Read next cluster
    mov ax, [cs:kernel_cluster]
    sub ax, 2
    mul byte [cs:sectors_per_cluster]
    add ax, [cs:start_sector]
    mov cl, [cs:sectors_per_cluster]
    call read_disk

    mov ax, [cs:bytes_per_sector]
    xor ch, ch
    mov cl, [cs:sectors_per_cluster]
    mul cx

    add bx, ax
    
    ; compute location of next cluster
    mov ax, [kernel_cluster]
    mov cx, 2
    mul cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; read entry from FAT table at index ax

    cmp ax, 0xFFF8                      ; end of chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    mov dl, [drive_number]

    mov bx, [part_lba]
    jmp 0:0x500


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
    push ax                             ; save registers
    push bx
    push cx
    push dx
    push di

    add ax, [part_lba]
    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    mov dl, [drive_number]
    mov ah, 02h

    int 13h
    jc .error                           ; error if carry flag is set

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers
    ret

.error:
    mov si, non_system_msg
    call print_string

    xor ah, ah
    int 0x16

    jmp 0xFFFF:0

print_string:       ; Routine: output string in SI to screen
	mov ah, 0x0E	; int 0x10 'print char' function

.loop:
	lodsb			; Get character from string
	cmp al, 0
	je .done		; If char is zero, end of string
	int 0x10		; Otherwise, print it
	jmp .loop

.done:
	ret

non_system_msg: db "Non-System disk or disk error", 0xA, 0xD, "Replace and strike any key when ready", 0

kernel: db "DAVIDOS SYS"

start_sector: dw 0
root_size: db 0

cylinder: dw 0
head: dw 0
sector: dw 0

part_lba: dw 0

kernel_cluster: dw 0

times 510-($-$$) db 0
dw 0xAA55

buffer: