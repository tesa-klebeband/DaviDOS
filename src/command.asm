[ORG 0x100]

mov ah, 0x9
mov dx, davidos_info_msg
int 0x21

mov [param + 4], ds

mov ah, 0x4A
mov bx, 0x1000
int 0x21

mov ah, 0x19
int 0x21
add al, 'A'
mov [drive_letter], al

mov ah, 0x47
mov si, directory_buffer
xor dl, dl
int 0x21

mov di, directory_buffer
mov cx, 64
xor al, al
repne scasb
dec di
mov [di], byte '$'

call execute_bat

initialize:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE

    mov ah, 0x4A
    mov dx, 0x1000
    int 0x21

    mov ah, 0x25
    mov dx, int_24h
    mov al, 0x24
    int 0x21
    mov dx, initialize
    mov al, 0x23
    int 0x21
    mov dx, initialize
    mov al, 0x22
    int 0x21

    mov ah, 0x4A
    mov bx, 0x1000
    int 0x21

    mov ah, 0x19
    int 0x21
    add al, 'A'
    mov [drive_letter], al

    mov ah, 0x47
    mov si, directory_buffer
    xor dl, dl
    int 0x21

    mov di, directory_buffer
    mov cx, 64
    xor al, al
    repne scasb
    dec di
    mov [di], byte '$'

print_prompt:
    mov ah, 0x9
    mov dx, newline
    int 0x21

    mov ah, 0x2
    mov dl, [drive_letter]
    int 0x21
    mov dl, ':'
    int 0x21
    mov dl, '\'
    int 0x21

    mov ah, 0x9
    mov dx, directory_buffer
    int 0x21

    mov ah, 0x2
    mov dl, '>'
    int 0x21

    xor al, al
    mov di, input_buffer
    mov cx, 281
    rep stosb

    xor bx, bx

get_input:
    mov ah, 1
    int 0x21

    cmp al, 0x8
    je .do_backspace

    mov [input_buffer + bx], al
    
    cmp al, 0xD
    je bind_results

    inc bx
    jmp get_input

.do_backspace:
    mov ah, 0x2
    mov dl, '>'
    int 0x21

    cmp bx, 0
    je get_input

    dec bx
    mov [input_buffer + bx], byte 0

    mov dl, 0x8
    int 0x21
    mov dl, ' '
    int 0x21
    mov dl, 0x8
    int 0x21
    jmp get_input

bind_results:
    cmp bx, 0
    je print_prompt

    push bx
    xor bx, bx

.get_cmdline_start:
    cmp [input_buffer + bx], byte '/'
    je .copy_filename
    cmp [input_buffer + bx], byte ' '
    je .copy_filename
    cmp [input_buffer + bx], byte 0xD
    je .copy_filename

    inc bx
    jmp .get_cmdline_start

.copy_filename:
    mov si, input_buffer
    mov di, filename
    mov cx, bx
    rep movsb

    pop cx
    sub cx, bx
    inc cx
    mov di, cmdline + 1
    push cx
    rep movsb

    pop cx
    dec cl
    mov [cmdline], cl

execute_file:
    mov al, '.'
    mov di, filename
    mov cx, 9
    repne scasb
    jne .no_bat

    cmp [di], word "ba"
    jne .no_bat
    cmp [di + 2], byte 't'
    jne .no_bat

    call execute_bat

    jmp initialize

.no_bat:
    cmp [bat_execution], byte 1
    je .execute

    push word initialize

.execute:
    
    cmp [bat_execution], byte 1
    je .check

    add sp, 2
    push word print_prompt

.check:
    cmp [filename + 1], byte ':'
    je change_drive

    mov si, cd_cmd
    mov di, filename
    mov cx, 3
    repe cmpsb
    je cd
    
    mov si, del_cmd
    mov di, filename
    mov cx, 4
    repe cmpsb
    je del

    mov si, ren_cmd
    mov di, filename
    mov cx, 4
    repe cmpsb
    je ren

    mov si, ver_cmd
    mov di, filename
    mov cx, 4
    repe cmpsb
    je ver

    mov si, cls_cmd
    mov di, filename
    mov cx, 4
    repe cmpsb
    je cls

    mov si, dir_cmd
    mov di, filename
    mov cx, 4
    repe cmpsb
    je dir

    mov si, echo_cmd
    mov di, filename
    mov cx, 5
    repe cmpsb
    je echo

    mov si, exit_cmd
    mov di, filename
    mov cx, 5
    repe cmpsb
    je exit

    mov si, type_cmd
    mov di, filename
    mov cx, 5
    repe cmpsb
    je type

    mov si, copy_cmd
    mov di, filename
    mov cx, 5
    repe cmpsb
    je copy

    mov si, pause_cmd
    mov di, filename
    mov cx, 6
    repe cmpsb
    je pause_

    mov ax, 0x4B00
    mov dx, filename
    mov bx, param
    int 0x21
    jnc .done

    mov di, filename
    xor al, al
    mov cx, 11
    repne scasb
    dec di
    mov [di], byte '.'
    mov [di + 1], byte 'C'
    mov [di + 2], byte 'O'
    mov [di + 3], byte 'M'

    mov ax, 0x4B00
    mov dx, filename
    mov bx, param
    int 0x21
    jnc .done

    mov di, filename
    mov al, '.'
    mov cx, 11
    repne scasb
    mov [di], byte 'E'
    mov [di + 1], byte 'X'
    mov [di + 2], byte 'E'

    mov ax, 0x4B00
    mov dx, filename
    mov bx, param
    int 0x21
    jnc .done

    mov ah, 0x9
    mov dx, bad_filename_msg
    int 0x21

.done:
    ret

change_drive:
    mov ah, 0xE
    mov dl, [filename]
    cmp dl, 'a'
    jl .letter_to_number
    cmp dl, 'z'
    jg invalid_drive

    sub dl, 'a'
    jmp .set_drive

.letter_to_number:
    sub dl, 'A'
    
.set_drive:
    int 0x21
    
    mov ah, 0x19
    int 0x21

    cmp al, dl
    jne invalid_drive

    add al, 'A'
    mov [drive_letter], al

    mov ah, 0x9
    mov dx, newline
    int 0x21

    ret

cd:
    cmp [cmdline], byte 0
    je syntax_error

    mov [filename + 1], byte 0

    mov si, cmdline + 2
    mov di, filename
    xor ch, ch
    mov cl, [cmdline]
    dec cl
    push cx
    rep movsb
    pop cx

    mov dx, filename
    mov ax, 0x3b00
    int 0x21

    jc invalid_dir

    mov ah, 0x47
    mov si, directory_buffer
    xor dl, dl
    int 0x21

    mov di, directory_buffer
    mov cx, 64
    xor al, al
    repne scasb
    dec di
    mov [di], byte '$'

    mov ah, 0x9
    mov dx, newline
    int 0x21

    ret

del:
    cmp [cmdline], byte 0
    je syntax_error

    mov [filename + 1], word 0

    mov si, cmdline + 2
    mov di, filename
    xor ch, ch
    mov cl, [cmdline]
    dec cl
    rep movsb

    mov ah, 0x41
    mov dx, filename
    int 0x21
    jc file_not_found

    mov ah, 0x9
    mov dx, newline
    int 0x21

    ret

ren:
    mov di, cmdline + 2
    mov al, ' '
    xor ch, ch
    mov cl, [cmdline]
    repne scasb
    jne syntax_error

    mov [filename + 1], word 0

    mov [di - 1], byte 0
    push di
    sub di, cmdline + 2
    xor ch, ch
    mov cl, [cmdline]
    sub cx, di
    pop di
    push di
    add di, cx
    dec di
    mov [di], byte 0
    pop di

    mov ah, 0x56
    mov dx, cmdline + 2
    int 0x21
    jc file_not_found

    mov ah, 0x9
    mov dx, newline
    int 0x21

    ret

echo:
    cmp [cmdline], byte 0
    je syntax_error

    mov di, cmdline + 1
    xor ch, ch
    mov cl, [cmdline]
    add di, cx
    mov [di], byte '$'
    
    mov ah, 0x9
    mov dx, newline
    int 0x21
    mov dx, cmdline + 2
    int 0x21
    mov dx, newline
    int 0x21

    ret

ver:
    mov ah, 0x9
    mov dx, davidos_ver_msg
    int 0x21
    mov dx, dos_ver_msg
    int 0x21

    mov ah, 0x30
    int 0x21
    push ax

    xor ah, ah
    call convert_to_dec
    mov ah, 0x9
    mov dx, ascii_int + 4
    int 0x21
    mov ah, 0x2
    mov dl, '.'
    int 0x21

    pop ax
    mov al, ah
    xor ah, ah
    call convert_to_dec
    mov ah, 0x9
    mov dx, ascii_int + 3
    int 0x21
    mov dx, newline
    int 0x21
    ret

cls:
    mov ax, 3
    int 0x10

    ret

pause_:
    mov ah, 0x9
    mov dx, press_any_key_to_continue_msg
    int 0x21

    mov ah, 0x8
    int 0x21

    ret

type:
    cmp [cmdline], byte 0
    je syntax_error

    mov ah, 0x1A
    mov dx, dta
    int 0x21

    mov [filename + 1], word 0
    mov [filename + 3], byte 0

    mov si, cmdline + 2
    mov di, filename
    xor ch, ch
    mov cl, [cmdline]
    dec cl
    rep movsb

    mov ah, 0x4E
    mov cx, 0b100111
    mov dx, filename
    int 0x21
    jc file_not_found

    cmp [dta + 0x1A], word 0
    je .return
    
    mov ax, 0x3D00
    mov dx, filename
    int 0x21

    mov bx, ax
    mov ah, 0x3F
    mov cx, [dta + 0x1A]
    mov dx, buffer
    int 0x21

    mov ah, 0x3E
    int 0x21

    mov ah, 0x2
    mov dl, 0xA
    int 0x21
    mov dl, 0xD
    int 0x21

    mov di, buffer
    add di, [dta + 0x1A]

    mov [di], byte '$'

    mov ah, 0x9
    mov dx, buffer
    int 0x21
    mov dx, newline
    int 0x21

.return:
    ret

exit:
    mov ax, 0x4C00
    int 0x21

dir:
    mov [filename], word "*."
    mov [filename + 2], byte '*'

    mov ah, 0x9
    mov dx, vol_in_drive_msg
    int 0x21
    mov dx, drive_letter
    int 0x21

    mov ah, 0x1A
    mov dx, dta
    int 0x21

    mov ah, 0x4E
    mov cx, 0b1000
    mov dx, filename
    int 0x21
    jnc .print_label

    mov ah, 0x9
    mov dx, no_label_msg
    int 0x21

    jmp .print_dir_info

.print_label:
    mov ah, 0x9
    mov dx, has_label_msg
    int 0x21

    xor al, al
    mov di, dta + 0x1E
    mov cx, 13
    repne scasb

    dec di
    mov [di], byte '$'
    mov ah, 0x9
    mov dx, dta + 0x1E
    int 0x21

.print_dir_info:
    mov ah, 0x9
    mov dx, newline
    int 0x21
    mov dx, dir_of_msg
    int 0x21
    mov dx, drive_letter
    int 0x21

    mov ah, 0x2
    mov dl, ':'
    int 0x21
    mov dl, '\'
    int 0x21

    mov ah, 0x9
    mov dx, directory_buffer
    int 0x21
    mov dx, newline
    int 0x21

    cmp [cmdline], byte 0
    je .find_first

    mov si, cmdline + 2
    mov di, filename
    xor ch, ch
    mov cl, [cmdline]
    dec cl
    rep movsb

    jmp .find_first

.find_first:
    mov ah, 0x4E
    mov cx, 0b110111
    mov dx, filename
    int 0x21
    jc file_not_found
    mov ah, 0x9
    mov dx, newline
    int 0x21

    mov bx, 1

.print_files:
    mov ah, 0x2
    mov si, dta + 0x1E
    mov cl, 13

.loop:
    lodsb
    mov dl, al
    cmp dl, 0
    je .fill_space
    int 0x21
    dec cl
    jmp .loop

.fill_space:
    cmp cx, 0
    je .done
    mov dl, ' '
    int 0x21
    dec cl
    jmp .fill_space

.done:
    mov ah, 0x9
    mov dx, placeholder
    int 0x21

    mov dl, [dta + 0x15]
    and dl, 0b10000
    cmp dl, 0
    je .print_size

    mov ah, 0x9
    mov dx, dir_msg
    int 0x21
    jmp .print_date

.print_size:
    mov ax, [dta + 0x1A]
    call convert_to_dec
    mov ah, 0x9
    mov dx, ascii_int
    int 0x21

.print_date:
    mov ah, 0x9
    mov dx, placeholder
    int 0x21

    mov ax, [dta + 0x18]
    shr ax, 5
    and ax, 0b1111
    call convert_to_dec
    mov ah, 0x9
    mov dx, ascii_int + 3
    int 0x21

    mov ah, 0x2
    mov dl, '-'
    int 0x21

    mov ax, [dta + 0x18]
    and ax, 0b11111
    call convert_to_dec
    mov ah, 0x9
    mov dx, ascii_int + 3
    int 0x21

    mov ah, 0x2
    mov dl, '-'
    int 0x21
    
    mov ax, [dta + 0x18]
    shr ax, 9
    add ax, 1980
    call convert_to_dec
    mov ah, 0x9
    mov dx, ascii_int + 3
    int 0x21

    mov ah, 0x9
    mov dx, placeholder
    int 0x21

    mov ax, [dta + 0x16]
    shr ax, 11
    call convert_to_dec
    mov ah, 0x9
    mov dx, ascii_int + 3
    int 0x21
    
    mov ah, 0x2
    mov dl, ':'
    int 0x21

    mov ax, [dta + 0x16]
    shr ax, 5
    and ax, 0b111111
    call convert_to_dec
    mov ah, 0x9
    mov dx, ascii_int + 3
    int 0x21

    mov ah, 0x9
    mov dx, newline
    int 0x21

    mov ah, 0x4F
    mov cx, 0b110111
    mov dx, filename
    int 0x21
    jc .print_num_of_files

    inc bx
    jmp .print_files

.print_num_of_files:
    mov ax, bx
    call convert_to_dec

    mov ah, 0x9
    mov dx, placeholder
    int 0x21
    int 0x21
    mov dx, ascii_int
    int 0x21
    mov dx, files_msg
    int 0x21
    mov dx, newline
    int 0x21

    ret

copy:
    mov ah, 0x1A
    mov dx, dta
    int 0x21

    mov di, cmdline + 2
    mov al, ' '
    xor ch, ch
    mov cl, [cmdline]
    repne scasb
    jne syntax_error

    mov [filename + 1], word 0

    mov [di - 1], byte 0
    push di
    sub di, cmdline + 2
    xor ch, ch
    mov cl, [cmdline]
    sub cx, di
    pop di
    push di
    add di, cx
    dec di
    mov [di], byte 0
    pop di

    mov ah, 0x4E
    mov cx, 0b100111
    mov dx, cmdline + 2
    int 0x21
    jc file_not_found

    cmp [dta + 0x1A], word 0
    je .return
    
    mov ax, 0x3D00
    mov dx, cmdline + 2
    int 0x21

    mov bx, ax
    mov ah, 0x3F
    mov cx, [dta + 0x1A]
    mov dx, buffer
    int 0x21

    mov ah, 0x3E
    int 0x21

    mov ah, 0x3C
    mov dx, di
    mov cx, 0x20
    int 0x21

    mov bx, ax
    mov ah, 0x40
    mov dx, buffer
    mov cx, [dta + 0x1A]
    int 0x21

.return:
    mov ah, 0x9
    mov dx, newline
    int 0x21

    ret

execute_bat:
    mov ah, 0x1A
    mov dx, bat_dta
    int 0x21

    mov ah, 0x4E
    mov cx, 0b100111
    mov dx, filename
    int 0x21
    jc file_not_found

    cmp [bat_dta + 0x1A], word 0
    je .end_bat
    
    mov ax, 0x3D00
    mov dx, filename
    int 0x21

    mov bx, ax
    mov ah, 0x3F
    mov cx, [bat_dta + 0x1A]
    mov dx, buffer
    int 0x21
    
    mov ah, 0x3E
    int 0x21

    mov [bat_execution], byte 1

    mov di, buffer

.get_next_line:
    push di

    xor al, al
    mov di, input_buffer
    mov cx, 281
    rep stosb

    pop di

    mov bx, di
    mov al, 0xA
    mov dx, bx
    sub dx, buffer
    mov cx, [bat_dta + 0x1A]
    sub cx, dx
    cmp cx, 0
    je .end_bat
    repne scasb
    jne .end_bat

    dec di
    mov [di], byte 0xD
    inc di

    mov cx, di
    sub cx, bx
    push cx

    push di
    mov si, bx
    mov di, input_buffer
    rep movsb
    pop di
    pop bx
    dec bx
    push di

    call bind_results

    pop di

    jmp .get_next_line

.end_bat:
    mov [bat_execution], byte 0

    ret

invalid_drive:
    mov ah, 0x9
    mov dx, invalid_drive_msg
    int 0x21

    ret

invalid_dir:
    mov ah, 0x9
    mov dx, invalid_dir_msg
    int 0x21

    ret

file_not_found:
    mov ah, 0x9
    mov dx, file_not_found_msg
    int 0x21

    ret

syntax_error:
    mov ah, 0x9
    mov dx, syntax_error_msg
    int 0x21

    ret

convert_to_dec:
    push ax
    push bx
    push dx
    xor dx, dx
    mov bx, 10000
    div bx
    add al, '0'
    mov [ascii_int], al
    mov ax, dx
    xor dx, dx
    mov bx, 1000
    div bx
    add al, '0'
    mov [ascii_int + 1], al
    mov ax, dx
    xor dx, dx
    mov bx, 100
    div bx
    add al, '0'
    mov [ascii_int + 2], al
    mov ax, dx
    xor dx, dx
    mov bx, 10
    div bx
    add al, '0'
    mov [ascii_int + 3], al
    mov ax, dx
    add al, '0'
    mov [ascii_int + 4], al

    pop dx
    pop bx
    pop ax
    ret

int_24h:
    push dx
    push ds
    push ax
    mov ax, cs
    mov ds, ax

    mov ah, 0x9
    mov dx, fail_msg
    int 0x21
    pop ax
    push ax
    and ah, 1
    cmp ah, 1
    je .write_fail
    
    mov ah, 0x9
    mov dx, reading_msg
    int 0x21

    jmp .print_drive

.write_fail:
    mov ah, 0x9
    mov dx, writing_msg
    int 0x21

.print_drive:
    mov ah, 0x9
    mov dx, drive_msg
    int 0x21

    pop ax
    mov dl, al
    add dl, 'A'
    mov ah, 0x2
    int 0x21

    mov ah, 0x9
    mov dx, abort_retry_ignote_msg
    int 0x21

    pop ds
    pop dx

.get_choice:
    xor ah, ah
    int 0x16
    mov ah, 0x0E
    
    cmp al, 'a'
    jl .upper_case

    sub al, 0x20

.upper_case:
    cmp al, 'A'
    je .abort
    cmp al, 'R'
    je .retry
    cmp al, 'I'
    je .ignore

    jmp .get_choice

.abort:
    int 0x10
    mov al, 0x2
    iret

.retry:
    int 0x10
    mov al, 0x1
    iret

.ignore:
    int 0x10
    mov al, 0
    iret

input_buffer: resb 140
filename: db "autoexec.bat", 0
cmdline: resb 128

param:
    dw 0
    dw cmdline
    dw 0
    dw 0
    dw 0
    dw 0
    dw 0

dta: resb 0x2B
bat_dta: resb 0x2B
directory_buffer: resb 64

bat_execution: db 0

cd_cmd: db "cd", 0
del_cmd: db "del", 0
ren_cmd: db "ren", 0
ver_cmd: db "ver", 0
cls_cmd: db "cls", 0
dir_cmd: db "dir", 0
echo_cmd: db "echo", 0
type_cmd: db "type", 0
copy_cmd: db "copy", 0
exit_cmd: db "exit", 0
pause_cmd: db "pause", 0

davidos_info_msg: db "DaviDOS(C) Version 1.0", 0xA, 0xD, "           (C)Copyright tesa_klebeband 2023.", 0xA, 0xD, '$'
davidos_ver_msg: db 0xA, 0xD, "DaviDOS(C) Version 1.0$"
dos_ver_msg: db 0xA, 0xD, "Emulated DOS version: $"
bad_filename_msg: db 0xA, 0xD, "Bad command or file name", 0xA, 0xD, '$'
invalid_drive_msg: db 0xA, 0xD, "Invalid drive specification", 0xA, 0xD, '$'
invalid_dir_msg: db 0xA, 0xD, "Invalid directory", 0xA, 0xD, '$'
file_not_found_msg: db 0xA, 0xD, "File not found", 0xA, 0xD, '$'
syntax_error_msg: db 0xA, 0xD, "Syntax error", 0xA, 0xD, '$'
press_any_key_to_continue_msg: db 0xA, 0xD, "Press any key to continue", 0xA, 0xD, '$'
vol_in_drive_msg: db 0xA, 0xD, "Volume in drive $"
no_label_msg: db ": has no label$"
has_label_msg: db ": is $"
dir_of_msg: db "Directory of $"
dir_msg: db "<DIR>$"
files_msg: db " file(s)$"
fail_msg: db 0xA, 0xD, "General failure while $"
reading_msg: db "reading from $"
writing_msg: db "writing to $"
drive_msg: db "drive $"
abort_retry_ignote_msg: db 0xA, 0xD, "(A)bort, (R)etry, (I)gnore? $"

newline: db 0xA, 0xD, '$'
drive_letter: db "@$"
ascii_int: db "     $"
placeholder: db "  $"

buffer: