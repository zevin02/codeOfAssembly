section .data
    string db 'abcdefghijklmnopqrstuvwxyz', 0  ; 添加字符串结束符

section .text
    global _start

_start:

    ;对cmos ram的访问需要通过两个端口来进行，0x70,0x74是索引端口，用来指定ram内部的单元
    ;0x71，0x75是数据端口，用来读写相应单元中的内容
    ;读取今天是星期几
    mov al,0x06  ;0x06偏移量代表的内容就是星期
    out 0x70,al     ;通过0x70这个索引端口，告诉ram内部的单元，我们现在要处理的单元是0x06星期 
    in al,0x71      ;把读取的星期数据从数据端口0x71中写入到al中
    ;0x70中的8个bit位是通过低7位来指定ram中的索引号，最高位来决定是否阻断所有的nmi信号


        ; 退出程序
    mov eax, 1       ; 系统调用号1表示exit
    xor ebx, ebx     ; 返回值为0
    int 0x80         ; 调用Linux内核的系统调用