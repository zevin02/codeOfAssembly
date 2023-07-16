section .data
    string db 'abcdefghijklmnopqrstuvwxyz', 0  ; 添加字符串结束符

section .text
    global _start

_start:
    ;主要嗯盘分配的端口号是0x1f0-0x1f7,8个端口
    ;一：写入要读取的扇区数
    ;设置要操作的端口号，由于in和out只能将数据写入到ax，al和dx，
    ; mov dx,0x1f2    ;表示写入的扇区号是0x1f2(里面的数值表示)

    ; ;如果这里给al写入的是0,表示要读取256个扇区
    ; mov al,0x01     ;表示要读取1个扇区,由于al是8位的，所以每次只能读取255个扇区
    ; out dx,al       ;把al写入到端口中，告知我此时要读取一个扇区数量

    ; ;每读取一个扇区，这个端口中的这个数值就会减1,如果在读写失败的情况下，这个端口中就包含了还没有读取的扇区个数有多少

    ; ;设置我们要从哪个LBA扇区号开始读取，由于扇区的读写是连续的，所以只需要给出第一个扇区的编号，后面就能连续读取我们要读取的扇区个数
    ; ;同时由于现在我们使用的是LBA28的标准，扇区号是由28位来构成的
    ; ;所以我们使用4个端口来存储这个LBA编号，分别是0x1f3,0x1f4,0x1f5,0x1f6这4个端口存储起始的LBA逻辑扇区号

    ; ;二。设置起始的LBA扇区号
    ; ;假设我们要读写的起始逻辑扇区号是0x02
    ; mov dx,0x1f3  ;0x1f3我们来放0-7位
    ; mov al,0x02
    ; out dx,al   ;把al写入到dx中0-7位，写入0x1f3
    ; inc dx          ;0x1f4
    ; mov al,0x00     ;0x00写入到0x1f4
    ; out dx,al 
    ; inc dx          ;0x1f5
    ; out dx,al 
    ; inc dx          ;0x1f6
    ; mov al,0xe0     ;LBA模式下，主硬盘，以及LBA地址24-27  0xe0:1110最低位的0表示使用的主硬盘，低6位的1表示使用的是LBA的扇区管理模式
    ; out dx,al 
    
    ; ;三。向端口0x1f7写入0x20
    ; mov dx,0x1f7
    ; mov al,0x20
    ; out dx,al 


    ;四：等待
    
    ; mov ah, 0x0f 
    ; shr ah,5
    xor dx,dx
    mov ax,0x1fff 
    sti
    mov bx, 0x2f11 
    mul bx

    ; 退出程序
    mov eax, 1       ; 系统调用号1表示exit
    xor ebx, ebx     ; 返回值为0
    int 0x80         ; 调用Linux内核的系统调用
