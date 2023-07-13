section .text
    global _start

_start:
    ; 初始化数据


    ;movsb，movsw是把数据从内存的一个地方批量的传送到另一个地方，处理器把他们看成字符串
    ;movsb传输以字节为单位，而movsw以字为单位
    ;neg 指令可以获得相反数0-dx
    ;cbw可以将byte扩展到word,cbw就是将al中的有符号数扩展到整个ax
    ;cwd就是将word转化成双字，将ax扩展到dx:ax
    ;处理器执行的结果和操作数的类型无关

    ;在处理的时候，数的视角要统一，无符号数和无符号数，有符号数和有符号数
    mov al,0x0a
    mov ah,0x03
    ; neg ah
    ; add al,ah
    ; sub ah,al
    ; ;add and sub all can deal with unsigned and signed
    ; mov ax,0x0400
    ; mov bl,0xf0
    ; ;div只能处理有符号的除法 
    ; ; div bl
    ; ;同时还提供了一个idiv来处理无符号的除法
    ; ; idiv bl
    ; ; xor dx,dx
    ; mov ax,0xf0c0
    ; cwd
    ; mov bx,0x11  ;处理的是16位的
    ; idiv bx
    cmp al,ah
    jg lbb

    lbb:
        ;测试zf标志位,上一次的算术逻辑运算才会影响flag寄存器
        sub ah,3
        jz lbz
        inc ah

    lbz:
        ;测试奇偶校验位
        inc ah 
        
        jnp lbl 
        dec ah 
    lbl:
        ;测试进位
        mov bl,0xf4
        add bl,0x11
        jc lbz
        inc bl 





    ; 退出程序
    mov eax, 1       ; 系统调用号1表示exit
    xor ebx, ebx     ; 返回值为0
    int 0x80         ; 调用Linux内核的系统调用
