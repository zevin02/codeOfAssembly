section .data
    string db 'abcdefghijklmnopqrstuvwxyz', 0  ; 添加字符串结束符

section .text
    global _start

_start:
    ; 初始化数据
    mov cx, 26
    mov bx, string

    lppush:
        mov al, [bx]
        push ax
        inc bx
        loop lppush

    mov cx, 26
    mov bx, string

    lppop:
        pop ax
        mov [bx], al
        inc bx
        loop lppop

    ; 退出程序
    mov eax, 1       ; 系统调用号1表示exit
    xor ebx, ebx     ; 返回值为0
    int 0x80         ; 调用Linux内核的系统调用
