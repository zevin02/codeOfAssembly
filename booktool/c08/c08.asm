         ;代码清单8-2
         ;文件名：c08.asm
         ;文件说明：用户程序 
         ;创建日期：2011-5-5 18:17
         
;===============================================================================
;第一个段的名字叫做header，表示程序的开头部分
;一旦定义段，那么后面的内容就都属于这个段，除非后面又出现了另一个段的定义
;如果不以段的定义开始，那么后面的就都属于一个段，除非后面又出现了其他的段的定义

;用户程序的头部，必须以一个段的形式存在，这样加载器方便获得
;用户程序的头部需要包含(1.用户程序的尺寸，以字节为单位的大小,加载器需要根据这个来决定读取多少个逻辑扇区
;2.应用程序的入口


SECTION header vstart=0                     ;定义用户程序头部段 
        ;program_length这个标号代表程序的总长度,
        ;用dd来声明一个双字，program_end用户程序的长度，标号汇编地址（由于他在trail段中没有vstart所以他的汇编地址是从程序开头开始的）
    program_length  dd program_end          ;程序总长度[0x00]
    
    ;用户程序入口点,需要给出段地址和偏移地址，理想情况下，入口点在代码段内偏移量为0的位置上，
    code_entry      dw start                ;偏移地址[0x04]，给出的偏移地址,由于在code_1段中被vstart声明，所以这里的start是想对这code_1段的汇编地址

                    dd section.code_1.start ;段地址[0x06] 给出了段地址

    ;由于用户定义的段的个数是不确定的，段重定向表的项目数是不确定的
    ;这里初始化并声明段重定向表的项目数
    realloc_tbl_len dw (header_end-code_1_segment)/4
                                            ;段重定位表项个数[0x0a]
;     section.header.start 这个表示这个段的开始地址，汇编地址
    
    ;段重定位表           
    ;用户程序可能不值一个段，大的程序可能会包含多个代码段和数据段，程序加载到内存后，每个段的地址都必须重新确定
    ;段的重定向是加载器的工作，需要知道每个段在用户程序中的什么位置，所以就需要在头部建立一张段重定向表
    ;定义实际的段重定向表
    ;依次计算段开始的汇编地址的表达式并进行初始化
    code_1_segment  dd section.code_1.start ;[0x0c]
    code_2_segment  dd section.code_2.start ;[0x10]
    data_1_segment  dd section.data_1.start ;[0x14]
    data_2_segment  dd section.data_2.start ;[0x18]
    stack_segment   dd section.stack.start  ;[0x1c]
    
    header_end:                
    
;===============================================================================
;第二个段的名字是code，代表的程序的代码段
;inter处理器要求段在内存中的起始物理地址是16字节对齐，物理地址必须是16的倍数
;align=16就代表16字节对其。align=32就说明是32字节对其
;尽管定义了段，但是引用某个标号的时候，仍然是从程序的开头开始计算汇编地址
;vstart=0表示标号要从该段的开头，0开始计算，而不是程序的开头
SECTION code_1 align=16 vstart=0         ;定义代码段1（16字节对齐） 
put_string:                              ;显示串(0结尾)。
                                         ;输入：DS:BX=串地址
         mov cl,[bx]
         or cl,cl                        ;cl=0 ?
         jz .exit                        ;是的，返回主程序 
         call put_char
         inc bx                          ;下一个字符 
         jmp put_string

   .exit:
         ret

;-------------------------------------------------------------------------------
put_char:                                ;显示一个字符
                                         ;输入：cl=字符ascii
         push ax
         push bx
         push cx
         push dx
         push ds
         push es

         ;以下取当前光标位置
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         mov dx,0x3d5
         in al,dx                        ;高8位 
         mov ah,al

         mov dx,0x3d4
         mov al,0x0f
         out dx,al
         mov dx,0x3d5
         in al,dx                        ;低8位 
         mov bx,ax                       ;BX=代表光标位置的16位数

         cmp cl,0x0d                     ;回车符？
         jnz .put_0a                     ;不是。看看是不是换行等字符 
         mov ax,bx                       ;此句略显多余，但去掉后还得改书，麻烦 
         mov bl,80                       
         div bl
         mul bl
         mov bx,ax
         jmp .set_cursor

 .put_0a:
         cmp cl,0x0a                     ;换行符？
         jnz .put_other                  ;不是，那就正常显示字符 
         add bx,80
         jmp .roll_screen

 .put_other:                             ;正常显示字符
         mov ax,0xb800
         mov es,ax
         shl bx,1
         mov [es:bx],cl

         ;以下将光标位置推进一个字符
         shr bx,1
         add bx,1

 .roll_screen:
         cmp bx,2000                     ;光标超出屏幕？滚屏
         jl .set_cursor

         mov ax,0xb800
         mov ds,ax
         mov es,ax
         cld
         mov si,0xa0
         mov di,0x00
         mov cx,1920
         rep movsw
         mov bx,3840                     ;清除屏幕最底一行
         mov cx,80
 .cls:
         mov word[es:bx],0x0720
         add bx,2
         loop .cls

         mov bx,1920

 .set_cursor:
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         mov dx,0x3d5
         mov al,bh
         out dx,al
         mov dx,0x3d4
         mov al,0x0f
         out dx,al
         mov dx,0x3d5
         mov al,bl
         out dx,al

         pop es
         pop ds
         pop dx
         pop cx
         pop bx
         pop ax

         ret

;-------------------------------------------------------------------------------
  start:
         ;初始执行时，DS和ES指向用户程序头部段
         mov ax,[stack_segment]           ;设置到用户程序自己的堆栈 
         mov ss,ax
         mov sp,stack_end
         
         mov ax,[data_1_segment]          ;设置到用户程序自己的数据段
         mov ds,ax

         mov bx,msg0
         call put_string                  ;显示第一段信息 

         push word [es:code_2_segment]
         mov ax,begin
         push ax                          ;可以直接push begin,80386+
         
         retf                             ;转移到代码段2执行 
         
  continue:
         mov ax,[es:data_2_segment]       ;段寄存器DS切换到数据段2 
         mov ds,ax
         
         mov bx,msg1
         call put_string                  ;显示第二段信息 

         jmp $ 

;===============================================================================
SECTION code_2 align=16 vstart=0          ;定义代码段2（16字节对齐）

  begin:
         push word [es:code_1_segment]
         mov ax,continue
         push ax                          ;可以直接push continue,80386+
         
         retf                             ;转移到代码段1接着执行 
         
;===============================================================================
;这个部分下面就是数据段
SECTION data_1 align=16 vstart=0

    msg0 db '  This is NASM - the famous Netwide Assembler. '
         db 'Back at SourceForge and in intensive development! '
         db 'Get the current versions from http://www.nasm.us/.'
         db 0x0d,0x0a,0x0d,0x0a
         db '  Example code for calculate 1+2+...+1000:',0x0d,0x0a,0x0d,0x0a
         db '     xor dx,dx',0x0d,0x0a
         db '     xor ax,ax',0x0d,0x0a
         db '     xor cx,cx',0x0d,0x0a
         db '  @@:',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     add ax,cx',0x0d,0x0a
         db '     adc dx,0',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     cmp cx,1000',0x0d,0x0a
         db '     jle @@',0x0d,0x0a
         db '     ... ...(Some other codes)',0x0d,0x0a,0x0d,0x0a
         db 0

;===============================================================================
SECTION data_2 align=16 vstart=0

    msg1 db '  The above contents is written by LeeChung. '
         db '2011-05-06'
         db 0

;===============================================================================
;section stack
SECTION stack align=16 vstart=0
           
         resb 256

stack_end:  

;===============================================================================
SECTION trail align=16
;这个地方没有写vstart，那么这里的program_end就是相对于程序开头的汇编地址
program_end: