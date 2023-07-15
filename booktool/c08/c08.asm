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
        ;ds:bx来表示字符串所在的段地址和偏移地址
        ;这个程序就是循环从ds:bx中取单个字符，判断是否为0,如果是0,说明读取结束了
         mov cl,[bx]                    ;读取数据放到cl中
         or cl,cl                        ;cl=0 ?

         jz .exit                        ;是的，返回主程序 ，说明这个字符串结束了
         ;如果不是0,说明这个就是我们需要打印的字符，就需要调用相应的函数
         call put_char
         inc bx                          ;下一个字符 
         jmp put_string                 ;重复这个过程

   .exit:
         ret;结束这个循环打印字符串，打印完之后，就能够返回了

;-------------------------------------------------------------------------------
put_char:                                ;显示一个字符
                                         ;输入：cl=字符ascii

        ;先将部分要使用的寄存器压栈，
         push ax
         push bx
         push cx
         push dx
         push ds
         push es

         ;以下取当前光标位置
         mov dx,0x3d4           ;获得索引寄存器，可以向这个索引寄存器写入一个值，指令内部的一个寄存器
         ;两个8位的光标寄存器的索引值分别是0x0e(14)和0x0f(15)他们分别用来提供馆标位置的高8位和低8位
         mov al,0x0e
         out dx,al              ;把索引值写入到dx中
         mov dx,0x3d5           ;指令了寄存器之后，就可以对这个寄存器写入进行读写，通过数据端口0x3f5来进行

         in al,dx                        ;高8位 从数据端口中读取高8位写入到al中
         mov ah,al                       ;把al设置成ah，代表高8位，之后就能使用ax表示这个光标的值了
        ;高值现在要读取的是0x0f号寄存器，获取馆标的低8位
         mov dx,0x3d4            ;
         mov al,0x0f
         out dx,al
         mov dx,0x3d5
         in al,dx                        ;低8位 
         ;组合成完整的ax
         mov bx,ax                       ;BX=代表光标位置的16位数



         cmp cl,0x0d                     ;回车符？
         jnz .put_0a                     ;不是。看看是不是换行等字符 
         ;到这里说明cl是回车符号
         ;如果是回车符号的话，就需要将当前光标移动到当前行的行首，每行有80个字符
         ;用当前行的行号除以80,不要余数，再乘以80,就可以得到当前行的行号

         mov ax,bx                       ;此句略显多余，但去掉后还得改书，麻烦 
         mov bl,80                       
         div bl                         ;除以80,获得行号，余数再ah中，商再al中

         mul bl                 ;将al乘上bl，在寄存器ax中得到当前行行首的光标值，
         ;相乘之后的结果就在ax中
         mov bx,ax
         jmp .set_cursor;跳转到设置光标的位置

 .put_0a:
        ;走到这里说明不是回车符号
         cmp cl,0x0a                     ;换行符？
         ;再判断是否是换行符号
         jnz .put_other                  ;不是，那就正常显示字符 
         ;这个就说明是换行符号,当前游标+80,跳转到屏幕的下一行取处理
         add bx,80
         jmp .roll_screen

 .put_other:                             ;正常显示字符
        ;正常打印字符
        ;
         mov ax,0xb800
         mov es,ax      ;将es设置到显存中
         shl bx,1       ;左边移1位，一个光标对应一个字符（一个字符对应2个字节）
        ;假如现在光标是10,那么就对应第10个字符，在物理内存中对应着第20个字节
         ;bx就是用来表示光标的位置，偏移地址
         mov [es:bx],cl         ;写入相应的数据

         ;以下将光标位置推进一个字符
         shr bx,1
         add bx,1       ;打印完了一个字符，光标要移动到下一个字符的位置

 .roll_screen:
        ;在这个地方判断是否滚屏幕
         cmp bx,2000                     ;光标超出屏幕？滚屏
         jl .set_cursor ;如果bx小于2000，就是一个正常的，就需要设置光标
         ;否则就需要进行一个滚动屏幕
        ;滚动屏幕就是将屏幕商的第2-25行的内容整体往上提一行，最后使用黑底白字来填充第25行，使这一行什么也不做
        ;就是将数据从一个内存区域移动到另一内存区域
        
         mov ax,0xb800
         mov ds,ax
         mov es,ax
         cld    ;清空df标志位，表示是正向传送的
         mov si,0xa0;设置原区域是从显存内偏移地址为0xa0的位置开始（第2行第1列）
         mov di,0x00    ;目标地址在0x00中（第一行第一列）
         mov cx,1920    ;移动24*80个字符，1920个字数

         rep movsw      ;重复移动
         ;屏幕最下面一行还是原来的内容，就想要进行清除
         mov bx,3840                     ;清除屏幕最底一行,第25行第1列的偏移地址是3840
         ;位次，需要循环写入黑底白字的空白字符到这一行中
         mov cx,80
 .cls:
         mov word[es:bx],0x0720
         add bx,2
         loop .cls

         mov bx,1920    ;滚屏幕之后，光标应该在最后一行的第一列，他的值是1920

 .set_cursor:
        ;不管是回车，换行，还是显示可以打印的字符，都需要给出光标位置的新数值,下面的工作就是按照给出的数值，在屏幕上设置光标
        ;光标要移动到的地址数据存储在bx中
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         ;指定完寄存器端口之后，就可以从0x3d5中写入数据了
         mov dx,0x3d5
         mov al,bh
         out dx,al;把高位bh写入到al中就是0x0e

        ;把低位dl写入到写入到al中，就是0x0f中
         mov dx,0x3d4
         mov al,0x0f
         out dx,al

         mov dx,0x3d5
         mov al,bl
         out dx,al

        ;游标设置之后，就能够进行返回了
         pop es
         pop ds
         pop dx
         pop cx
         pop bx
         pop ax

         ret;返回到put_string中

;-------------------------------------------------------------------------------
;现在程序跳转到了用户程序，由于程序已经完成了重定向，所以现在要处理的就是初始化各个段寄存器DS，ES，SS,这样就能够访问自己专属的数据

  start:
        ;在刚刚进入这个用户程序的时候，ds和es还是指向header，而ss依然指向的是加载器的栈空间
         ;初始执行时，DS和ES指向用户程序头部段
         mov ax,[stack_segment]           ;设置到用户程序自己的堆栈 
         mov ss,ax                      ;
         mov sp,stack_end               ; 将这个设置为栈指针，栈的结束偏移地址，这个就是相当于mov sp,256
         
         ;堆栈切换完之后，就要获得数据段的地址
         mov ax,[data_1_segment]          ;设置到用户程序自己的数据段
         mov ds,ax

         mov bx,msg0                    ;将该段的起始地址写入到bx中
         ;并且调用函数来打赢
         call put_string                  ;显示第一段信息 

         push word [es:code_2_segment]   ;现在栈中压入code_2的段低值，
         mov ax,begin
         push ax                          ;可以直接push begin,80386+，再压入偏移地址
         
         retf                             ;转移到代码段2执行 ,retf会从栈定取出来偏移地址和段地址
         
  continue:
         mov ax,[es:data_2_segment]       ;段寄存器DS切换到数据段2 
         mov ds,ax              ;设置data_2的段地址传送到段寄存器ds中，相当于就换了一个数据段来处理
         
         mov bx,msg1
         call put_string                  ;显示第二段信息 

        ;用户程序执行完之后，一般都重新把控制返回到加载器中，加载器可以重新加载和运行其他的程序，所有的操作系统都是这么完成的
        
         jmp $  ;但是我们的加载器无法实现这个功能，而用户程序也没有将控制权返回给加载器,直接就进入了无限循环

;===============================================================================
SECTION code_2 align=16 vstart=0          ;定义代码段2（16字节对齐）

  begin:        ;偏移地址
         push word [es:code_1_segment]
         mov ax,continue
         push ax                          ;可以直接push continue,80386+
         
         retf                             ;转移到代码段1接着执行 
         
;===============================================================================
;这个部分下面就是数据段
SECTION data_1 align=16 vstart=0
;这个就是要显示的内容，在这里凡是需要回车和换行的都使用0x0d和0x0a来显示，最后一个是0用来标志字符串的结束
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
;这个是栈段，我们会用来更新
SECTION stack align=16 vstart=0
           ;空出来256个字节，供我们使用
         ;  resb 是一个伪命令，从当前位置开始保留指定数量的字节，但是不初始化他们的值，在原程序编译的时候编译器会保留一段内存空间
         ;用来存放编译之后的内容，跳过这个空间，这里面的空间的每个值是不确定的
         ;resb,resw(处理字),resd(处理双字),
         resb 256
;所以这个stack_end的汇编地址就是256
stack_end:  

;===============================================================================
SECTION trail align=16
;这个地方没有写vstart，那么这里的program_end就是相对于程序开头的汇编地址
program_end: