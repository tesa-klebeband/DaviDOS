[ORG 0x500]
[BITS 16]

mov ds, [cs:zero]
mov es, [cs:zero]

mov [cs:default_drive], dl
mov [cs:part_lba], bx
sub dl, 0x80 - 2
mov [cs:logical_drive], dl

cli
mov ax, 0x7000
mov ss, ax
mov sp, 0xFFFF

mov [0x84], word int_21h
mov [0x86], word 0
sti

mov [cs:dir_cluster], word 0
mov [cs:entry_offset], word 0
mov [cs:start_entry], word 0

mov ah, 0x25
mov dx, div_by_0
xor al, al
int 0x21

mov ah, 0x25
mov dx, int_24h
mov al, 0x24
int 0x21

mov ah, 0x25
mov dx, end_program
mov al, 0x22
int 0x21

mov ah, 0x25
mov dx, load_command
mov al, 0x23
int 0x21

mov ah, 0x25
mov dx, end_program
mov al, 0x20
int 0x21

mov ah, 0x25
mov dx, int_29h
mov al, 0x29
int 0x21

mov ah, 0x9
mov dx, starting_davidos_msg
int 0x21

call detect_partitions

load_command:
    mov ah, 0x4B
    xor al, al
    mov dx, cmd
    mov bx, param
    int 0x21

get_interpreter:
    mov ah, 0x9
    mov dx, command_load_error_msg
    int 0x21

    mov ah, 0x2
    mov dl, [cs:logical_drive]
    add dl, 'A'
    int 0x21
    mov dl, '>'
    int 0x21

    xor al, al
    mov di, cmd
    mov cx, 13
    rep stosb

    xor bx, bx

.loop:
    mov ah, 0x1
    int 0x21

    cmp al, 0xD
    je load_command
    cmp al, 0x8
    je get_interpreter

    mov [cs:cmd + bx], al
    cmp bx, 13
    je load_command
    inc bx

    jmp .loop

div_by_0:
    push cs
    pop ds

    mov ah, 0x9
    mov dx, div_by_zero_msg
    int 0x21

    add sp, 6
    int 0x20

int_21h:
    clc
    mov [cs:error_level], byte 0

    cmp ah, 0x0
    je end_program
    cmp ah, 0x1
    je print_stdin
    cmp ah, 0x2
    je print_char
    cmp ah, 0x6
    je console_io_no_check
    cmp ah, 0x7
    je read_stdin_no_check
    cmp ah, 0x8
    je read_stdin
    cmp ah, 0x9
    je print_string
    cmp ah, 0x0E
    je set_drive
    cmp ah, 0x19
    je get_drive
    cmp ah, 0x1A
    je set_dta
    cmp ah, 0x25
    je set_interrupt_vector
    cmp ah, 0x35
    je get_interrupt_vector
    cmp ah, 0x47
    je get_current_directory
    cmp ah, 0x48
    je allocate_memory
    cmp ah, 0x49
    je free_memory
    cmp ah, 0x4A
    je resize_memory
    cmp ah, 0x4C
    je end_program
    cmp ah, 0x4D
    je get_end_code
    cmp ah, 0x31
    je end_program_keep_memory
    cmp ah, 0x30
    je get_version
    cmp ah, 0x59
    je get_extendet_error

    call check_and_load_dir
    mov [cs:entry_offset], word 0
    mov [cs:start_entry], word 0
    cmp ah, 0x4B
    je program_operations
    cmp ah, 0x3B
    je change_directory
    cmp ah, 0x4E
    je find_first
    cmp ah, 0x4F
    je find_next
    cmp ah, 0x41
    je delete_file
    cmp ah, 0x56
    je rename_file
    cmp ah, 0x3D
    je open_file
    cmp ah, 0x3E
    je close_file
    cmp ah, 0x40
    je write_to_handle
    cmp ah, 0x3F
    je read_handle
    cmp ah, 0x3C
    je create_file

    mov [cs:error_level], byte 1
    mov ax, 1

    jmp return_21h

end_program:
    mov [cs:end_code], al

    sub [cs:mcb_offset], word 2
    mov si, mcb_exec_table
    add si, [cs:mcb_offset]

    mov ax, [cs:si]

    mov ds, ax

    mov [1], word 0

    sub [cs:reg_save_offset], word 16
    cmp [cs:reg_save_offset], word 0
    je command_exit

    mov si, reg_save
    add si, [cs:reg_save_offset]

    mov ss, [cs:si]
    mov sp, [cs:si + 2]
    mov ds, [cs:si + 4]
    mov es, [cs:si + 6]

    jmp return_21h

end_program_keep_memory:
    mov [cs:end_code], al

    sub [cs:mcb_offset], word 2
    mov si, mcb_exec_table
    add si, [cs:mcb_offset]

    mov ax, [cs:si]

    mov ds, ax

    mov [3], dx
    cmp [cs:reg_save_offset], word 16
    je command_exit
    sub [cs:reg_save_offset], word 16

    mov si, reg_save
    add si, [cs:reg_save_offset]

    mov ss, [cs:si]
    mov sp, [cs:si + 2]
    mov ds, [cs:si + 4]
    mov es, [cs:si + 6]

    jmp return_21h

command_exit:
    mov ds, [cs:zero]
    mov es, [cs:zero]
    mov ax, 0x7000
    mov ss, ax
    mov sp, 0xFFFF
    jmp load_command

print_stdin:
    mov [cs:tmp_8], ah
    mov ah, 0
    int 0x16
    call check_ctrl_c
    int 0x29
    mov ah, [cs:tmp_8]
    jmp return_21h

print_char:
    push ax
    mov al, dl
    call check_ctrl_c
    int 0x29
    pop ax
    jmp return_21h

console_io_no_check:
    cmp dl, 0xFF
    je read_stdin_no_check
    push ax
    mov al, dl
    int 0x29
    pop ax
    jz .zero
    jmp return_21h
.zero:
    xor al, al
    jmp return_21h

read_stdin_no_check:
    push ax
    mov ah, 0
    int 0x16
    pop ax
    jmp return_21h

read_stdin:
    push ax
    mov ah, 0
    int 0x16
    call check_ctrl_c
    pop ax
    jmp return_21h

print_string:
    push ax
    push si
    mov si, dx

.loop:
    lodsb
    cmp al, '$'
    je .done
    int 0x29
    jmp .loop

.done:
    pop si
    pop ax
    jmp return_21h

set_drive:
    call detect_partitions
    cmp dl, 2
    jge .check_mapping
    stc
    jmp return_21h

.check_mapping:
    push dx
    push di
    sub dl, 2
    xor dh, dh
    shl dx, 1
    mov di, part_map
    add di, dx
    cmp [cs:di], byte 0
    jne .drive_valid

    pop di
    pop dx

    stc
    jmp return_21h

.drive_valid:
    shr dx, 1
    add dl, 2
    mov [cs:logical_drive], dl

    mov dh, [cs:di + 1]
    mov dl, [cs:di]
    mov [cs:default_drive], dl
    mov [cs:dir_cluster], word 0
    mov [cs:dir_offset], word 0

    push ax
    push bx
    push cx
    push es

    cmp dh, 0xFF
    jne .use_partition_table
    mov [cs:part_lba], word 0
    jmp .clear_dir_buff

.use_partition_table:
    xor ax, ax
    mov cl, 1
    mov es, [cs:zero]
    mov bx, buffer
    mov [cs:part_lba], word 0
    call read_disk

    mov dl, dh
    xor dh, dh
    shl dx, 4
    mov di, buffer
    add di, dx
    mov bx, [cs:di + 446 + 8]
    mov [cs:part_lba], bx

.clear_dir_buff:
    mov di, current_directory_buffer
    xor al, al
    mov cx, 64
    rep stosb

    pop es
    pop cx
    pop bx
    pop ax
    pop di
    pop dx

    jmp return_21h

get_drive:
    mov al, [cs:logical_drive]
    jmp return_21h

set_dta:
    mov [cs:dta_segment], ds
    mov [cs:dta_offset], dx

    jmp return_21h

set_interrupt_vector:
    push ax
    push bx
    cli
    mov bl, 4
    mul bl
    mov bx, ax
    mov [cs:bx], dx
    mov [cs:bx + 2], ds
    sti
    pop bx
    pop ax
    jmp return_21h

get_interrupt_vector:
    push ax
    push si
    mov bl, 4
    mul bl
    mov si, ax
    mov bx, [cs:si]
    mov es, [cs:si + 2]
    pop si
    pop ax
    jmp return_21h

program_operations:
    cmp al, 0
    je load_and_execute_program

    mov ax, 1
    stc
    mov [cs:error_level], byte 1
    jmp return_21h

load_and_execute_program:
    push ds
    mov ax, ds
    cmp ax, 0
    jne .allocate_memory

    add ax, 0x2000
    mov [cs:allocated_memory_segment], ax
    mov [cs:allocated_memory_offset], word 0x100
    jmp .start_loading_file

.allocate_memory:
    dec ax
    mov ds, ax

.search_next_mcb:
    mov ax, [1]
    add ax, [3]
    mov ds, ax
    cmp [0], byte 'M'
    je .mcb_found
    jmp .mcb_free

.mcb_found:
    cmp [1], word 0
    je .mcb_free
    jmp .search_next_mcb

.mcb_free:
    inc ax
    mov [cs:allocated_memory_segment], ax
    mov [cs:allocated_memory_offset], word 0x100

.start_loading_file:
    pop ds
    call parse_filename
    mov [cs:search_attribute], byte 0b100111
    call search_entry
    jc return_21h

    mov si, reg_save
    add si, [cs:reg_save_offset]

    mov [cs:si], ss
    mov [cs:si + 2], sp
    mov [cs:si + 4], ds
    mov [cs:si + 6], es

    add [cs:reg_save_offset], word 16

    call load_file
    jc return_21h

    mov ax, [cs:allocated_memory_segment]
    mov ds, ax
    cmp [0x100], word "MZ"
    je .setup_exe
    cmp [0x100], word "ZM"
    je .setup_exe

    push es
    dec ax
    mov es, ax
    xor di, di

    mov [es:di], byte 'M'
    inc ax
    mov [es:di + 1], ax
    mov [es:di + 3], word 0xFFFF
    
    mov di, 8
    mov ds, [cs:zero]
    mov si, filename
    mov cx, 8
    rep movsb

    pop es

    dec ax
    mov si, mcb_exec_table
    add si, [cs:mcb_offset]
    mov [cs:si], ax
    add [cs:mcb_offset], word 2
    inc ax

    mov ds, [es:bx + 4]
    mov si, [es:bx + 2]
    mov es, ax
    xor di, di
    mov [es:di], word 0x20cd
    mov di, 0x80
    xor ch, ch
    mov cl, [ds:si]
    add cl, 2
    rep movsb

    mov ax, [cs:allocated_memory_segment]
    mov es, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0xFFFE
    push ds
    push 0x100

    mov ah, 0x2
    mov dl, 0xA
    int 0x21
    mov dl, 0xD
    int 0x21

    retf

.setup_exe:
    add ax, 0x10
    push ax
    push bx
    push es
    
    dec ax
    mov es, ax
    xor di, di

    mov [es:di], byte 'M'
    inc ax
    mov [es:di + 1], ax
    mov [es:di + 3], word 0xFFFF
    
    mov di, 8
    mov ds, [cs:zero]
    mov si, filename
    mov cx, 8
    rep movsb

    dec ax
    mov si, mcb_exec_table
    add si, [cs:mcb_offset]
    mov [cs:si], ax
    add [cs:mcb_offset], word 2
    inc ax

    mov ds, ax

    add ax, [0x8]
    mov cx, [0x6]
    mov bx, [0x18]

    jcxz .relocation_done

.relocation_cycle:
    mov di, [bx]
    mov dx, [bx+2]
    add dx, ax

    push ds
    mov ds, dx
    add [di], ax
    pop ds

    add bx, 4

    dec cx
    jcxz .relocation_done
    jmp .relocation_cycle

.relocation_done:
    pop es
    pop cx
    pop dx

    mov bx, ax
    add bx, [0xE]
    mov ss, bx
    mov sp, [0x10]
    add ax, [0x16]

    push ax
    push word [0x14]

    push ds
    mov bx, cx
    mov ds, [es:bx + 4]
    mov si, [es:bx + 2]
    mov es, dx
    xor di, di
    mov [es:di], word 0x20cd
    mov di, 0x80
    xor ch, ch
    mov cl, [ds:si]
    add cl, 2
    rep movsb
    pop ds

    mov ah, 0x2
    mov dl, 0xA
    int 0x21
    mov dl, 0xD
    int 0x21

    retf

allocate_memory:
    push ds
    mov ax, ds
    dec ax
    
.find_free_mcb:
    mov ds, ax
    cmp [1], word 0
    je .mcb_free
    cmp [0], byte 'M'
    jne .mcb_free
    mov ax, [1]
    add ax, [3]
    jmp .find_free_mcb

.mcb_free:
    mov [0], byte 'M'
    inc ax
    mov [1], ax
    mov [3], bx
    pop ds
    jmp return_21h

free_memory:
    push ds
    mov ax, es
    dec ax
    mov ds, ax
    mov [1], word 0
    pop ds
    jmp return_21h
    
resize_memory:
    push ds
    mov ax, es
    dec ax
    mov ds, ax
    mov [3], bx
    pop ds
    jmp return_21h

get_end_code:
    mov al, [cs:end_code]
    jmp return_21h

change_directory:
    call parse_filename
    mov [cs:search_attribute], byte 0x10
    call search_dir
    jc return_21h

    push cx
    push di
    push si
    push ds
    push es

    mov ds, [cs:zero]
    mov es, [cs:zero]

    mov di, current_directory_buffer
    add di, [cs:dir_offset]

    cmp [cs:filename], word '..'
    je .search_last
    cmp [cs:filename], byte '.'
    je .return
    
    cmp [cs:dir_offset], word 0
    je .copy_name
    mov [cs:di], byte '\'
    inc di

.copy_name:
    mov si, asciiz_filename
    xor ch, ch
    mov cl, [cs:filename_lenght]
    rep movsb

    mov [cs:di], byte 0
    
    sub di, current_directory_buffer
    mov [cs:dir_offset], di

    jmp .return

.search_last:
    dec di
    cmp [cs:di - 1], byte 0
    je .found_last
    cmp [cs:di], byte '\'
    je .found_last
    jmp .search_last

.found_last:
    mov [cs:di], byte 0
    sub di, current_directory_buffer
    mov [cs:dir_offset], di

.return:
    pop es
    pop ds
    pop si
    pop di
    pop cx

    jmp return_21h

get_current_directory:
    cmp dl, 0
    jne return_21h

    push di
    push si
    push ds
    push cx

    push ds
    pop es

    mov ds, [cs:zero]

    mov di, si
    mov si, current_directory_buffer
    mov cx, 64
    rep movsb

    pop cx
    pop ds
    pop si
    pop di

    jmp return_21h
    
find_first:
    call parse_filename
    push si
    push di
    push dx
    push cx
    push bx
    push es
    push ds

    mov bx, 0x1000
    mov es, bx
    xor bx, bx

    mov [cs:search_attribute], cl
    xor cx, cx

.search_loop:
    cmp [cs:filename], byte '*'
    je .search_extension
    cmp [cs:filename + 8], byte '*'
    je .search_entryname

    call search_entry
    jc .return
    
    mov bx, [cs:entry_offset]
    jmp .get_file_info

.search_extension:
    cmp [cs:filename + 8], byte '*'
    je .check_entry

    mov dx, [cs:filename + 8]
    cmp [es:bx + 8], dx
    jne .search_next_entry
    mov dl, [cs:filename + 10]
    cmp [es:bx + 10], dl
    jne .search_next_entry
    jmp .check_entry

.search_entryname:
    mov dx, [cs:filename]
    cmp [es:bx], dx
    jne .search_next_entry
    mov dx, [cs:filename + 2]
    cmp [es:bx + 2], dx
    jne .search_next_entry
    mov dx, [cs:filename + 4]
    cmp [es:bx + 4], dx
    jne .search_next_entry
    mov dx, [cs:filename + 6]
    cmp [es:bx + 6], dx
    jne .search_next_entry

.check_entry:
    cmp [es:bx], byte 0xE5
    je .search_next_entry
    cmp [es:bx], byte 0
    je .search_next_entry

    cmp [es:bx + 11], byte 0xF
    je .search_next_entry

    mov dl, [es:bx + 11]
    and dl, [cs:search_attribute]
    cmp dl, 0
    jne .get_file_info

    cmp [cs:search_attribute], byte 0
    jne .search_next_entry

    mov dl, [es:bx + 11]
    and dl, 0b11000
    cmp dl, 0
    je .get_file_info

.search_next_entry:
    add bx, 32
    inc cx
    cmp cx, [cs:total_dir_entries]
    jl .search_loop

.not_found:
    stc
    mov [cs:error_level], byte 1
    mov ax, 0x2
    jmp .return

.get_file_info:
    mov es, [cs:dta_segment]
    mov di, [cs:dta_offset]

    mov dl, [cs:search_attribute]
    mov [es:di], dl
    mov dl, [cs:default_drive]
    mov [es:di + 1], dl

    push cx
    push di
    add di, 2
    mov cx, 11
    mov si, filename
    mov ds, [cs:zero]
    rep movsb
    pop di
    pop cx

    push word 0x1000
    pop ds

    mov [es:di + 0xD], cx
    mov dx, [cs:dir_cluster]
    mov [es:di + 0xF], dx
    mov [es:di + 0x13], dx
    mov dl, [ds:bx + 11]
    mov [es:di + 0x15], dl
    mov dx, [ds:bx + 0x16]
    mov [es:di + 0x16], dx
    mov dx, [ds:bx + 0x18]
    mov [es:di + 0x18], dx
    mov dx, [ds:bx + 0x1C]
    mov [es:di + 0x1A], dx
    
    mov si, bx
    add di, 0x1E
    xor cx, cx
.name_loop:
    cmp [ds:si], byte ' '
    je .extension_copy
    cmp cx, 8
    je .extension_copy
    
    mov dl, [ds:si]
    mov [es:di], dl

    inc cx
    inc si
    inc di
    jmp .name_loop

.extension_copy:
    mov si, bx
    cmp [ds:si + 8], byte ' '
    jne .has_extension

    mov [es:di], byte 0
    jmp .return

.has_extension:
    mov [es:di], byte '.'
    inc di
    mov dx, [ds:si + 8]
    mov [es:di], dx
    mov dl, [ds:si + 10]
    mov [es:di + 2], dl
    mov [es:di + 3], byte 0
    clc

.return:
    pop ds
    pop es
    pop bx
    pop cx
    pop dx
    pop di
    pop si

    jmp return_21h

find_next:
    push ds
    push dx
    mov ds, [cs:dta_segment]
    mov dx, [cs:dta_offset]
    add dx, 0x1E
    call parse_filename
    pop dx
    pop ds
    push si
    push di
    push dx
    push cx
    push bx
    push es
    push ds

    mov bx, 0x1000
    mov es, bx
    xor bx, bx

    call search_entry
    jc .return

    mov [cs:search_attribute], cl
    mov bx, [cs:entry_offset]
    add bx, 32
    mov [cs:start_entry], bx
    call parse_filename
    xor cx, cx

.search_loop:
    cmp [cs:filename], byte '*'
    je .search_extension
    cmp [cs:filename + 8], byte '*'
    je .search_entryname

    call search_entry
    jc .return
    mov bx, [cs:entry_offset]
    jmp .get_file_info

.search_extension:
    cmp [cs:filename + 8], byte '*'
    je .check_entry

    mov dx, [cs:filename + 8]
    cmp [es:bx + 8], dx
    jne .search_next_entry
    mov dl, [cs:filename + 10]
    cmp [es:bx + 10], dl
    jne .search_next_entry
    jmp .check_entry

.search_entryname:
    mov dx, [cs:filename]
    cmp [es:bx], dx
    jne .search_next_entry
    mov dx, [cs:filename + 2]
    cmp [es:bx + 2], dx
    jne .search_next_entry
    mov dx, [cs:filename + 4]
    cmp [es:bx + 4], dx
    jne .search_next_entry
    mov dx, [cs:filename + 6]
    cmp [es:bx + 6], dx
    jne .search_next_entry

.check_entry:
    cmp [es:bx], byte 0xE5
    je .search_next_entry
    cmp [es:bx], byte 0
    je .not_found

    cmp [es:bx + 11], byte 0xF
    je .search_next_entry

    mov dl, [es:bx + 11]
    and dl, [cs:search_attribute]
    cmp dl, 0
    jne .get_file_info

    cmp [cs:search_attribute], byte 0
    jne .search_next_entry

    mov dl, [es:bx + 11]
    and dl, 0b11000
    cmp dl, 0
    je .get_file_info

.search_next_entry:
    add bx, 32
    inc cx
    cmp cx, [cs:total_dir_entries]
    jl .search_loop

.not_found:
    stc
    mov [cs:error_level], byte 1
    mov ax, 0x2
    jmp .return

.get_file_info:
    mov es, [cs:dta_segment]
    mov di, [cs:dta_offset]

    mov dl, [cs:search_attribute]
    mov [es:di], dl
    mov dl, [cs:default_drive]
    mov [es:di + 1], dl

    push di
    add di, 2
    mov cx, 11
    mov si, filename
    mov ds, [cs:zero]
    rep movsb
    pop di

    push word 0x1000
    pop ds

    mov [es:di + 0xD], cx
    mov dx, [cs:dir_cluster]
    mov [es:di + 0xF], dx
    mov [es:di + 0x13], dx
    mov dl, [ds:bx + 11]
    mov [es:di + 0x15], dl
    mov dx, [ds:bx + 0x16]
    mov [es:di + 0x16], dx
    mov dx, [ds:bx + 0x18]
    mov [es:di + 0x18], dx
    mov dx, [ds:bx + 0x1C]
    mov [es:di + 0x1A], dx

    mov si, bx
    add di, 0x1E
    xor cx, cx
.name_loop:
    cmp [ds:si], byte ' '
    je .extension_copy
    cmp cx, 8
    je .extension_copy
    
    mov dl, [ds:si]
    mov [es:di], dl

    inc cx
    inc si
    inc di
    jmp .name_loop

.extension_copy:
    mov si, bx
    cmp [ds:si + 8], byte ' '
    jne .has_extension

    mov [es:di], byte 0
    jmp .return

.has_extension:
    mov [es:di], byte '.'
    inc di
    mov dx, [ds:si + 8]
    mov [es:di], dx
    mov dl, [ds:si + 10]
    mov [es:di + 2], dl
    mov [es:di + 3], byte 0
    clc

.return:
    pop ds
    pop es
    pop bx
    pop cx
    pop dx
    pop di
    pop si

    jmp return_21h

rename_file:
    call parse_filename
    mov [cs:search_attribute], byte 0b111111
    call search_entry
    jc return_21h

    push ds
    push es
    push cx
    push di
    push si
    push es
    pop ds
    push dx
    mov dx, di
    call parse_filename

    mov ds, [cs:zero]
    mov cx, 0x1000
    mov es, cx
    mov si, filename
    mov di, [cs:entry_offset]
    mov cx, 11
    rep movsb

    pop dx
    pop si
    pop di
    pop cx
    pop es
    pop ds

    call check_and_write_dir
    jmp return_21h

delete_file:
    mov [cs:search_attribute], byte 0b100111
    call parse_filename
    call search_entry
    jc return_21h

    push es
    push ax
    push bx
    push cx
    push dx
    push di
    push si

    mov di, [cs:entry_offset]
    push word 0x1000
    pop es
    mov [es:di], byte 0xE5
    call check_and_write_dir

    mov ax, [cs:file_cluster]
    mov [cs:cluster], ax
    
    mov es, [cs:zero]
    mov ax, [cs:reserved_sectors]
    mov cl, [cs:sectors_per_fat]
    mov bx, buffer
    call read_disk
    jc .return

.next_cluster:
    cmp [cs:cluster], word 0xFFF8
    jae .end

    mov ax, [cs:cluster]
    mov cx, 2
    mul cx

    mov si, buffer
    add si, ax
    mov ax, [cs:si]
    
    mov [cs:cluster], ax

    mov [cs:si], word 0
    jmp .next_cluster

.end:
    mov es, [cs:zero]
    mov ax, [cs:reserved_sectors]
    mov cl, [cs:sectors_per_fat]
    mov bx, buffer
    call write_disk

    mov es, [cs:zero]
    mov ax, [cs:reserved_sectors]
    xor ch, ch
    mov cl, [cs:sectors_per_fat]
    add ax, cx
    mov bx, buffer
    call write_disk

.return:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es

    jmp return_21h

open_file:
    mov [cs:search_attribute], byte 0b100111
    call parse_filename
    call search_entry
    jc return_21h

    push ds
    push es
    push si
    push di
    push cx

    mov ds, [cs:zero]
    mov es, [cs:zero]

    push ax
    mov al, 0xFF
    mov di, handle_table
    mov cx, 192
    repne scasb
    jne .no_free_handles
    dec di
    pop ax
    mov [di], al

    sub di, 11
    push di
    mov si, filename
    mov cx, 11
    rep movsb

    pop ax
    sub ax, handle_table
    mov cl, 12
    div cl
    
    pop cx
    pop di
    pop si
    pop es
    pop ds

    jmp return_21h

.no_free_handles:
    mov ax, 4
    mov [cs:error_level], byte 1
    jmp return_21h

.invalid_open_mode:
    mov ax, 0xC
    mov [cs:error_level], byte 1
    jmp return_21h

close_file:
    push ax
    push cx
    push bx

    mov ax, bx
    mov cx, 12
    mul cx
    mov bx, ax
    add bx, handle_table
    mov [cs:bx + 11], byte 0xFF

    pop bx
    pop cx
    pop ax

    jmp return_21h

write_to_handle:
    cmp bx, 1
    je .not_writable
    cmp bx, 3
    je .not_writable
    cmp bx, 4
    je .not_writable
    cmp bx, 2
    je .write_stdout
    cmp bx, 3
    je .write_stdout

    push ds
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    push si

    mov [cs:write_buffer], dx
    mov [cs:write_size], cx

    mov ax, bx
    mov cx, 12
    mul cx

    push ds
    mov ds, [cs:zero]
    mov es, [cs:zero]

    mov si, handle_table
    add si, ax
    mov di, filename
    mov cx, 11
    rep movsb
    pop es

    mov [cs:search_attribute], byte 0b100111
    call search_entry
    jc .return

    mov ax, [cs:file_cluster]
    mov [cs:cluster], ax
    
    push es
    mov es, [cs:zero]
    mov ax, [cs:reserved_sectors]
    mov cl, [cs:sectors_per_fat]
    mov bx, buffer
    call read_disk
    jc .return
    pop es

    mov ax, [cs:sectors_per_fat]
    mul byte [cs:fat_copies]
    add ax, [cs:reserved_sectors]
    add al, [cs:root_size]
    mov [cs:start_sector], ax

    xor dx, dx
    mov ax, [cs:write_size]
    div word [cs:sectors_per_cluster]
    test dx, dx
    jz .divide_bps

    inc ax

.divide_bps:
    xor dx, dx
    div word [cs:bytes_per_sector]
    test dx, dx
    jz .save_clusters
    inc ax

.save_clusters:
    mov dx, ax
    push dx

    cmp [cs:cluster], word 0
    je .end_erasing

.next_cluster:
    mov ax, [cs:cluster]
    mov cx, 2
    mul cx

    mov si, buffer
    add si, ax
    mov ax, [cs:si]
    cmp ax, 0xFFF8
    jae .end_erasing
    
    mov [cs:cluster], ax

    mov [cs:si], word 0
    jmp .next_cluster

.end_erasing:
    mov [cs:si], word 0
    pop dx

    mov si, buffer + 6

.find_first_free:
    cmp [cs:si], word 0
    je .found_first_free

    add si, 2
    jmp .find_first_free

.found_first_free:
    push si

.found_free:
    push dx
    mov ax, si
    sub ax, buffer

    shr ax, 1
    
    sub ax, 2
    mul byte [cs:sectors_per_cluster]
    add ax, [cs:start_sector]
    mov cl, [cs:sectors_per_cluster]
    mov bx, [cs:write_buffer]
    call write_disk
    mov ax, [cs:bytes_per_sector]
    xor ch, ch
    mov cl, [cs:sectors_per_cluster]
    mov ax, [cs:bytes_per_sector]
    xor ch, ch
    mov cl, [cs:sectors_per_cluster]
    mul cx
    add [cs:write_buffer], ax

    pop dx
    dec dx

    test dx, dx
    jz .write_changes

    push si

    add si, 2
.find_next_free:
    cmp [cs:si], word 0
    je .found_next_free

    add si, 2
    jmp .find_next_free

.found_next_free:
    pop di
    mov bx, si
    sub bx, buffer
    shr bx, 1
    mov [cs:di], bx
    jmp .found_free

.write_changes:
    mov [cs:si], word 0xFFFF

    mov es, [cs:zero]
    mov ax, [cs:reserved_sectors]
    mov cl, [cs:sectors_per_fat]
    mov bx, buffer
    call write_disk

    mov es, [cs:zero]
    mov ax, [cs:reserved_sectors]
    xor ch, ch
    mov cl, [cs:sectors_per_fat]
    add ax, cx
    mov bx, buffer
    call write_disk

    mov cx, [cs:write_size]
    push word 0x1000
    pop es
    mov di, [cs:entry_offset]
    mov [es:di + 28], cx
    pop si
    sub si, buffer
    shr si, 1
    mov [es:di + 26], si

    call check_and_write_dir

.return:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop ds

    jmp return_21h

.write_stdout:
    push si
    push cx
    push ax

    mov si, dx

.stdout_loop:
    cmp cx, 0
    je .stdout_done
    lodsb
    int 0x29
    dec cx
    jmp .stdout_loop

.stdout_done:
    pop ax
    pop cx
    pop si

    jmp return_21h

.not_writable:
    mov [cs:error_level], byte 1
    mov ax, 0x6
    jmp return_21h

read_handle:
    push ax
    push cx
    push di
    push dx

    mov cx, 12
    mov ax, bx
    mul cx

    mov di, ax
    add di, handle_table

    cmp [cs:di + 11], byte 0
    
    pop dx
    pop di
    pop cx
    pop ax

    jne .not_readable

    cmp bx, 0
    je .read_stdin
    
    mov [cs:allocated_memory_segment], word 0x1000
    mov [cs:allocated_memory_offset], word 0

    push dx
    push ds
    push es
    push cx
    push si
    push di
    push ax
    
    mov ax, bx
    mov cx, 12
    mul cx

    mov ds, [cs:zero]
    mov es, [cs:zero]

    mov si, handle_table
    add si, ax
    mov di, filename
    mov cx, 11
    rep movsb

    pop ax
    pop di
    pop si
    pop cx
    pop es
    pop ds
    pop dx

    mov [cs:search_attribute], byte 0b100111
    call search_entry
    jc return_21h
    call load_file
    jc return_21h

    push ds
    push es
    push cx
    push si
    push di
    
    mov di, dx
    push ds
    pop es
    mov ds, [cs:allocated_memory_segment]
    xor si, si
    rep movsb

    pop di
    pop si
    pop cx
    pop es
    pop ds

    jmp return_21h

.read_stdin:
    push ax
    push si
    push cx

    mov si, dx

.stdin_loop:
    cmp cx, 0
    je .stdin_done
    xor ax, ax
    int 0x16
    mov [ds:si], al
    inc si
    dec cx
    jmp .stdin_loop

.stdin_done:
    pop cx
    pop si
    pop ax

    jmp return_21h

.not_readable:
    mov [cs:error_level], byte 1
    mov ax, 0x6
    jmp return_21h

create_file:
    call parse_filename

    push di
    push si
    push ds
    push es
    push cx

    xor di, di
    push word 0x1000
    pop es
    
.search_free:
    cmp [es:di], byte 0
    je .copy_filename
    cmp [es:di], byte 0xE5
    je .copy_filename

    add di, 32
    jmp .search_free

.copy_filename:
    mov [es:di + 11], cl
    mov [es:di + 28], word 0
    mov [es:di + 26], word 0

    mov ds, [cs:zero]
    mov si, filename
    mov cx, 11
    rep movsb

    call check_and_write_dir

.return:
    pop cx
    pop es
    pop ds
    pop si
    pop di    

    mov al, 0x2
    jmp open_file

get_version:
    mov al, 0x6
    mov ah, 22
    jmp return_21h

get_extendet_error:
    mov ax, [cs:error_code]
    jmp return_21h

return_21h:
    cmp [cs:error_level], byte 1
    je .set_carry

    add sp, 4
    popf
    clc
    pushf
    sub sp, 4

    iret

.set_carry:
    mov [cs:error_code], ax

    add sp, 4
    popf
    stc
    pushf
    sub sp, 4
    iret

check_ctrl_c:
    cmp al, 0x03
    je .ctrl_c_detected
    ret

.ctrl_c_detected:
    add sp, 2
    mov al, '^'
    int 0x29
    mov al, 'C'
    int 0x29

    int 0x23

unparse_bios_drive:
    push dx
    and dl, 0x80
    cmp dl, 0x80
    je .harddrive
    pop dx
    ret

.harddrive:
    pop dx
    sub dl, 0x80 - 2
    ret

parse_filename:
    push es
    push di
    push cx
    push bx
    push dx
    push ax
    push si

    mov ax, cs
    mov es, ax

    mov al, ' '
    mov di, filename
    mov cx, 11
    rep stosb

    xor al, al
    mov di, asciiz_filename
    mov cx, 13
    rep stosb

    mov bx, filename
    mov di, asciiz_filename
    mov si, dx

    cmp [ds:si], word '..'
    je .dot_dot_entry
    cmp [ds:si], byte '.'
    je .dot_entry

    xor cx, cx
.loop:
    mov al, [ds:si]
    cmp al, 0
    je .end

    inc cx

    mov [es:di], al

    cmp al, '.'
    je .complete_dot
    cmp al, 'A'
    jle .check_lowercase

.check_lowercase:
    cmp al, 'a'
    jl .add_to_filename
    cmp al, 'z'
    jg .add_to_filename

    sub al, 0x20

.add_to_filename:
    mov [es:bx], al
    inc bx
    inc di
    inc si
    jmp .loop

.complete_dot:
    inc si
    inc di
    mov bx, filename + 8
    jmp .loop

.dot_entry:
    mov al, [ds:si]
    mov [es:bx], al
    mov [es:di], al
    jmp .end

.dot_dot_entry:
    mov ax, [ds:si]
    mov [es:bx], ax
    mov [es:di], ax
    
.end:
    mov [cs:filename_lenght], cl

    pop si
    pop ax
    pop dx
    pop bx
    pop cx
    pop di
    pop es
    ret

setup_drive_read:
    push es
    push ds
    push ax
    push bx
    push cx
    push dx
    push di

    push es
    mov ah, 0x8
    mov dl, [cs:default_drive]
    clc
    int 0x13
    pop es
    jc .error
    and cl, 0x3F
    xor ch, ch
    mov [cs:sectors_per_track], cx
    inc dh
    mov [cs:heads], dh

    xor ax, ax
    mov cl, 1
    push es
    mov es, [cs:zero]
    mov bx, buffer
    call read_disk
    pop es

    cmp [cs:buffer + 0x26], byte 0x29
    jne .fat_error

    mov dx, [cs:buffer + 0xB]
    mov [cs:bytes_per_sector], dx
    mov dl, [cs:buffer + 0xD]
    mov [cs:sectors_per_cluster], dl
    mov dx, [cs:buffer + 0xE]
    mov [cs:reserved_sectors], dx
    mov dl, [cs:buffer + 0x10]
    mov [cs:fat_copies], dl
    mov dx, [cs:buffer + 0x11]
    mov [cs:total_dir_entries], dx
    mov dx, [cs:buffer + 0x16]
    mov [cs:sectors_per_fat], dx
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop ds
    pop es

    ret

.error:
    mov [cs:tmp_8], ah
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop ds
    pop es

    mov ah, [cs:tmp_8]
    call handle_disk_error

    cmp [cs:choice], byte 0x1
    je setup_drive_read

    jmp .done

.fat_error:
    push cs
    pop ds
    mov ah, 0x9
    mov dx, bad_fat_msg
    int 0x21

    int 0x22

.done:
    ret

check_and_load_dir:
    call setup_drive_read
    jc .return

    cmp [cs:dir_cluster], word 0
    je load_root
    jmp load_dir

.return:
    ret

check_and_write_dir:
    call setup_drive_read
    jc .return

    cmp [cs:dir_cluster], word 0
    je write_root
    jmp write_dir

.return:
    ret

load_root:
    push ax
    push bx
    push cx
    push es
    push dx
    
    xor bx, bx
    mov es, bx

    mov ax, [cs:sectors_per_fat]
    mov bl, [cs:fat_copies]
    mul bx
    add ax, [cs:reserved_sectors]
    push ax

    xor bx, bx
    xor ax, ax

    mov ax, [cs:total_dir_entries]
    mov bl, 32
    mul bx

    div word [cs:bytes_per_sector]

    mov cl, al
    mov [cs:root_size], cl
    pop ax

    mov bx, 0x1000
    mov es, bx
    xor bx, bx

    call read_disk

    pop dx
    pop es
    pop cx
    pop bx
    pop ax

    ret

write_root:
    push ax
    push bx
    push cx
    push es
    push dx
    
    xor bx, bx
    mov es, bx

    mov ax, [cs:sectors_per_fat]
    mov bl, [cs:fat_copies]
    mul bx
    add ax, [cs:reserved_sectors]

    mov cl, [cs:root_size]
    mov [cs:root_size], cl

    mov bx, 0x1000
    mov es, bx
    xor bx, bx  

    call write_disk

    pop dx
    pop es
    pop cx
    pop bx
    pop ax

    ret

search_entry:
    push ds
    push es
    push bx
    push si
    push di
    push cx

    mov ds, [cs:zero]
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    mov di, [cs:start_entry]

.search_loop:
    mov cx, 11
    mov si, filename
    push di
    repe cmpsb
    pop di
    je .found_file
    add di, 32
    inc bx
    cmp bx, [cs:total_dir_entries]
    jl .search_loop

    stc
    mov [cs:error_level], byte 1
    mov ax, 2
    jmp .return

.found_file:
    mov bl, [es:di + 0xB]
    and bl, [cs:search_attribute]
    cmp bl, 0
    jne .get_cluster

    stc
    mov [cs:error_level], byte 1
    mov ax, 2
    jmp .return

.get_cluster:
    mov bx, [es:di + 26]
    mov [cs:file_cluster], bx
    mov bx, [es:di + 28]
    mov [cs:file_size], bx
    mov [cs:entry_offset], di
    clc

.return:
    pop cx
    pop di
    pop si
    pop bx
    pop es
    pop ds

    ret

search_dir:
    push ds
    push es
    push bx
    push si
    push di
    push cx

    mov ds, [cs:zero]
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    mov di, [cs:start_entry]

.search_loop:
    mov cx, 11
    mov si, filename
    push di
    repe cmpsb
    pop di
    je .found_dir
    add di, 32
    inc bx
    cmp bx, [cs:total_dir_entries]
    jl .search_loop

    stc
    mov [cs:error_level], byte 1
    mov ax, 3
    jmp .return

.found_dir:
    mov bl, [es:di + 0xB]
    and bl, [cs:search_attribute]
    cmp bl, 0
    jne .get_cluster

    stc
    mov [cs:error_level], byte 1
    mov ax, 3
    jmp .return

.get_cluster:
    mov bx, [es:di + 26]
    mov [cs:dir_cluster], bx
    mov [cs:entry_offset], di
    clc

.return:
    pop cx
    pop di
    pop si
    pop bx
    pop es
    pop ds

    ret

load_file:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds

    mov es, [cs:zero]

    mov ax, [cs:file_cluster]           ; First cluster field
    mov [cs:cluster], ax
    
    mov ax, [cs:reserved_sectors]
    mov cl, [cs:sectors_per_fat]
    mov bx, buffer
    call read_disk
    jc .end

    mov es, [cs:allocated_memory_segment]
    mov bx, [cs:allocated_memory_offset]

    mov ax, [cs:sectors_per_fat]
    mul byte [cs:fat_copies]
    add ax, [cs:reserved_sectors]
    add al, [cs:root_size]
    mov [cs:start_sector], ax

.load_file_loop:
    mov ax, [cs:cluster]
    sub ax, 2
    mul byte [cs:sectors_per_cluster]
    add ax, [cs:start_sector]
    mov cl, [cs:sectors_per_cluster]
    call read_disk
    jc .end

    mov ax, [cs:bytes_per_sector]
    xor ch, ch
    mov cl, [cs:sectors_per_cluster]
    mul cx

    add bx, ax
    
    ; compute location of next cluster
    mov ax, [cs:cluster]
    mov cx, 2
    mul cx

    mov si, buffer
    add si, ax
    mov ax, [cs:si]                     ; read entry from FAT table at index ax

    cmp ax, 0xFFF8                      ; end of chain
    jae .end

    mov [cs:cluster], ax
    jmp .load_file_loop

.end:
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret

write_dir:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds

    mov es, [cs:zero]

    mov ax, [cs:dir_cluster]
    mov [cs:cluster], ax
    
    mov ax, [cs:reserved_sectors]
    mov cl, [cs:sectors_per_fat]
    mov bx, buffer
    call read_disk
    jc .end

    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    mov ax, [cs:sectors_per_fat]
    mul byte [cs:fat_copies]
    add ax, [cs:reserved_sectors]
    add al, [cs:root_size]
    mov [cs:start_sector], ax

.write_dir_loop:
    mov ax, [cs:cluster]
    sub ax, 2
    mul byte [cs:sectors_per_cluster]
    add ax, [cs:start_sector]
    mov cl, [cs:sectors_per_cluster]
    call write_disk
    jc .end

    mov ax, [cs:bytes_per_sector]
    xor ch, ch
    mov cl, [cs:sectors_per_cluster]
    mul cx

    add bx, ax
    ; compute location of next cluster
    mov ax, [cs:cluster]
    mov cx, 2
    mul cx

    mov si, buffer
    add si, ax
    mov ax, [cs:si]                     ; read entry from FAT table at index ax

    cmp ax, 0xFFF8                      ; end of chain
    jae .end

    mov [cs:cluster], ax
    jmp .write_dir_loop

.end:
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret

load_dir:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds

    mov es, [cs:zero]

    mov ax, [cs:dir_cluster]
    mov [cs:cluster], ax
    
    mov ax, [cs:reserved_sectors]
    mov cl, [cs:sectors_per_fat]
    mov bx, buffer
    call read_disk
    jc .end

    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    mov ax, [cs:sectors_per_fat]
    mul byte [cs:fat_copies]
    add ax, [cs:reserved_sectors]
    add al, [cs:root_size]
    mov [cs:start_sector], ax

.load_dir_loop:
    mov ax, [cs:cluster]
    sub ax, 2
    mul byte [cs:sectors_per_cluster]
    add ax, [cs:start_sector]
    mov cl, [cs:sectors_per_cluster]
    call read_disk
    jc .end

    mov ax, [cs:bytes_per_sector]
    xor ch, ch
    mov cl, [cs:sectors_per_cluster]
    mul cx

    add bx, ax
    
    ; compute location of next cluster
    mov ax, [cs:cluster]
    mov cx, 2
    mul cx

    mov si, buffer
    add si, ax
    mov ax, [cs:si]                     ; read entry from FAT table at index ax

    cmp ax, 0xFFF8                      ; end of chain
    jae .end

    mov [cs:cluster], ax
    jmp .load_dir_loop

.end:
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret

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

read_disk:
    push ax
    push bx
    push cx
    push dx
    push di

    add ax, [cs:part_lba]
    push cx
    call lba_to_chs
    pop ax
    mov dl, [cs:default_drive]
    mov ah, 0x2
    mov [cs:tmp_8], ah

    int 0x13

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    jnc .done

    call handle_disk_error

    cmp [cs:choice], byte 0x1
    je read_disk

.done:
    ret

write_disk:
    push ax
    push bx
    push cx
    push dx
    push di

    add ax, [cs:part_lba]
    push cx
    call lba_to_chs
    pop ax
    mov dl, [cs:default_drive]
    mov ah, 0x3
    mov [cs:tmp_8], ah

    clc
    int 0x13

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    jnc .done

    call handle_disk_error

    cmp [cs:choice], byte 0x1
    je read_disk

.done:
    ret

handle_disk_error:
    push ax
    mov al, [cs:logical_drive]
    cmp [cs:tmp_8], byte 0x3
    je .write_error

    xor ah, ah
    int 0x24
    jmp .save_choice

.write_error:
    mov ah, 1
    int 0x24

.save_choice:
    mov [cs:choice], al
    pop ax

.done:
    cmp [cs:choice], byte 0x2
    je .abort

    ret

.abort:
    int 0x22

detect_partitions:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    mov di, part_map
    mov dl, 0x80
    mov es, [cs:zero]

.drive_loop:
    push dx
    mov ah, 0x2
    mov al, 1
    xor dh, dh
    mov cl, 1
    xor ch, ch
    mov bx, buffer
    int 0x13
    pop dx
    jc .done

    cmp [cs:buffer + 510], word 0xAA55
    jne .drive_done

    cmp [cs:buffer + 0x39], word "16"           ; Part of FAT16 identifier
    jne .part_1
    mov [cs:di], dl
    mov [cs:di + 1], byte 0xFF
    add di, 2

.part_1:
    cmp [cs:buffer + 446 + 4], byte 0x4
    jne .part_2
    mov [cs:di], dl
    mov [cs:di + 1], byte 0
    add di, 2
.part_2:
    cmp [cs:buffer + 446 + 4 + 16], byte 0x4
    jne .part_3
    mov [cs:di], dl
    mov [cs:di + 1], byte 1
    add di, 2
.part_3:
    cmp [cs:buffer + 446 + 4 + 32], byte 0x4
    jne .part_4
    mov [cs:di], dl
    mov [cs:di + 1], byte 2
    add di, 2
.part_4:
    cmp [cs:buffer + 446 + 4 + 48], byte 0x4
    jne .drive_done
    mov [cs:di], dl
    mov [cs:di + 1], byte 3
    add di, 2

.drive_done:
    inc dl
    jmp .drive_loop

.done:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax

    ret
    
int_24h:
    xor al, al
    iret

int_29h:
    push ax
    mov ah,0xE
    int 0x10
    pop ax

    iret

bytes_per_sector: dw 0
sectors_per_track: dw 0
sectors_per_cluster: dw 0
reserved_sectors: dw 0
heads: dw 0
sectors_per_fat: dw 0
total_dir_entries: dw 0
fat_copies: db 0
default_drive: db 0
logical_drive: db 0
part_lba: dw 0
fat_version_string: db "FAT16   "

zero: dw 0

end_code: db 0
choice: db 0
error_code: dw 0
error_level: db 0

filename_lenght: db 0
filename: db "           ", 0
asciiz_filename: resb 13
file_cluster: dw 0
dir_cluster: dw 0
cluster: dw 0
root_size: db 0
start_sector: dw 0
search_attribute: db 0
entry_offset: dw 0
file_size: dw 0
start_entry: dw 0
write_buffer: dw 0
write_size: dw 0

cylinder: dw 0
head: dw 0
sector: dw 0

starting_davidos_msg: db 0xA, 0xD, "Starting DaviDOS...", 0xA, 0xD, 0xA, 0xD, '$'
command_load_error_msg: db 0xA, 0xD, "Bad or missing command interpreter", 0xA, 0xD, "Enter correct name of Command Interpreter (eg, COMMAND.COM)", 0xA, 0xD, 0xA, 0xD, '$'
div_by_zero_msg: db 0xA, 0xD, "Divide by zero", 0xA, 0xD, '$'
bad_fat_msg: db 0xA, 0xD, "Bad File Allocation Table$"

allocated_memory_segment: dw 0
allocated_memory_offset: dw 0

dta_segment: dw 0
dta_offset: dw 0

tmp_8: db 0
tmp_16: dw 0

reg_save:
    resb 128
    reg_save_offset: dw 0

db 0
current_directory_buffer:
    resb 64
    dir_offset: dw 0

handle_table:
    db "STDIN      ", 0
    db "STDOUT     ", 1
    db "STDERR     ", 1
    db "STDAUX     ", 1
    db "STDPRN     ", 1
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF
    db "           ", 0xFF

mcb_exec_table:
    resb 64
    mcb_offset: dw 0

cmd: db "command.com", 0
param:
    dw 0
    dw cmdline
    dw 0
    dw 0
    dw 0
    dw 0
    dw 0

cmdline: 
    db 0
    db 0xD

part_map:
    resw 23                             ; 23 possible partitions for 23 possible drive letters (C-Z)
                                        ; Each words consists of drive number and partitons

buffer: