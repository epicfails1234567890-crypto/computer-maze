[BITS 16]
[ORG 0x7C00]

inicio:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov ax, 0x0003
    int 0x10

    ; Cargar datos iniciales en RAM (0x8000) - Rellenar con ceros (vacío)
    mov di, 0x8000
    mov si, datos_iniciales
    mov cl, 48
    rep movsb

    mov byte [dir_actual], '/'
    mov byte [dir_actual+1], 0

    mov si, txt_init
    call imprimir

prompt:
    mov si, dir_actual
    call imprimir
    mov si, txt_p
    call imprimir

    mov di, buf_cmd

leer:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D             ; ENTER
    je ejecutar

    cmp al, 0x08             ; BACKSPACE
    je borrar

    stosb
    mov ah, 0x0E
    int 0x10
    jmp leer

borrar:
    cmp di, buf_cmd
    je leer
    dec di
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp leer

ejecutar:
    mov byte [di], 0
    mov si, txt_nl
    call imprimir

    cmp byte [buf_cmd], 0
    je prompt

    ; --- EVALUAR COMANDOS ---
    cmp word [buf_cmd], 736Ch   ; 'ls'
    je do_ls

    cmp word [buf_cmd], 7770h   ; 'pwd'
    je do_pwd

    cmp word [buf_cmd], 6C63h   ; 'cls'
    je do_cls

    cmp word [buf_cmd], 646Dh   ; 'md' ('m'=6Dh, 'd'=64h)
    je do_md

    cmp word [buf_cmd], 6D72h   ; 'rm'
    je do_rm

    cmp word [buf_cmd], 6463h   ; 'cd'
    je do_cd

    mov si, txt_err
    call imprimir
    jmp prompt

do_pwd:
    mov si, dir_actual
    call imprimir
    mov si, txt_nl
    call imprimir
    jmp prompt

do_cls:
    mov ax, 0x0003
    int 0x10
    jmp prompt

do_ls:
    cmp byte [dir_actual + 1], 0
    jne .fin_ls

    mov bx, 0x8000
    mov cl, 8
.loop:
    push cx
    cmp byte [bx], 0
    je .next
    mov al, [bx + 11]
    mov si, txt_file
    cmp al, 0x01
    je .print_t
    mov si, txt_dir
.print_t:
    call imprimir
    mov si, bx
    mov cl, 11
.print_n:
    lodsb
    mov ah, 0x0E
    int 0x10
    loop .print_n
    mov si, txt_nl
    call imprimir
.next:
    add bx, 16
    pop cx
    loop .loop
.fin_ls:
    jmp prompt

do_md:
    mov si, buf_cmd + 3
    mov bx, 0x8000
    mov cl, 8
.find:
    cmp byte [bx], 0
    je .create
    add bx, 16
    loop .find
    jmp prompt

.create:
    mov di, bx
    mov al, ' '
    push cx
    mov cl, 11
    rep stosb
    pop cx
    mov di, bx
.copy:
    lodsb
    or al, al
    jz .done
    stosb
    jmp .copy
.done:
    mov byte [bx + 11], 0x02
    jmp prompt

do_rm:
    mov si, buf_cmd + 3
    mov bx, 0x8000
    mov cl, 8
.find:
    cmp byte [bx], 0
    je .next
    mov al, [si]
    cmp al, [bx]
    je .del
.next:
    add bx, 16
    loop .find
    jmp prompt

.del:
    mov byte [bx], 0
    jmp prompt

do_cd:
    mov si, buf_cmd + 3
    cmp word [si], 2E2Eh        ; '..'
    je .root

    ; Comprueba si el directorio existe buscando la inicial
    mov bx, 0x8000
    mov cl, 8
.find:
    cmp byte [bx], 0
    je .next
    mov al, [si]
    cmp al, [bx]
    je .found
.next:
    add bx, 16
    loop .find

    mov si, txt_err
    call imprimir
    jmp prompt

.found:
    mov di, dir_actual + 1
.copy:
    lodsb
    or al, al
    jz .end
    stosb
    jmp .copy
.end:
    mov byte [di], 0
    jmp prompt

.root:
    mov byte [dir_actual], '/'
    mov byte [dir_actual+1], 0
    jmp prompt

imprimir:
    lodsb
    or al, al
    jz .fin
    mov ah, 0x0E
    int 0x10
    jmp imprimir
.fin:
    ret

; --- CADENAS Y BUFFERS ---
txt_init:    db 'OS', 13, 10, 0
txt_p:        db '> ', 0
txt_nl:       db 13, 10, 0
txt_err:      db 'Err', 13, 10, 0
txt_file:     db 'F:', 0
txt_dir:      db 'D:', 0

datos_iniciales:
    times 48 db 0

dir_actual:   times 6 db 0
buf_cmd:      times 10 db 0

; Relleno exacto de 512 bytes
times 510-($-$$) db 0
dw 0xAA55