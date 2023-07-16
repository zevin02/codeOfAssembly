         ;代码清单9-1
         ;文件名：c09_1.asm
         ;文件说明：用户程序 
         ;创建日期：2011-4-16 22:03
          
;===============================================================================
;程序的头部，供加载器读取
SECTION header vstart=0                     ;定义用户程序头部段 
    program_length  dd program_end          ;程序总长度[0x00]程序的总大小
    
    ;用户程序入口点
    code_entry      dw start                ;偏移地址[0x04]程序的偏移地址
                    dd section.code.start   ;段地址[0x06]  程序的入口的段地址
    
    realloc_tbl_len dw (header_end-realloc_begin)/4             
                                            ;段重定位表项个数[0x0a] 具体的段个数，每个段4个字节
    
    realloc_begin:
    ;段重定位表           定义段重定向的汇编地址，后期会在加载其中，把这些在该程序中的段汇编地址转化成为物理内存的段地址
    code_segment    dd section.code.start   ;[0x0c]
    data_segment    dd section.data.start   ;[0x14]
    stack_segment   dd section.stack.start  ;[0x1c]
    
header_end:                
    
;===============================================================================
;程序入口的段地址
SECTION code align=16 vstart=0           ;定义代码段（16字节对齐） 
new_int_0x70:
      push ax
      push bx
      push cx
      push dx
      push es
      
  .w0:                                    
      mov al,0x0a                        ;阻断NMI。当然，通常是不必要的
      or al,0x80                          
      out 0x70,al
      in al,0x71                         ;读寄存器A
      test al,0x80                       ;测试第7位UIP 
      jnz .w0                            ;以上代码对于更新周期结束中断来说 
                                         ;是不必要的 
      xor al,al
      or al,0x80
      out 0x70,al
      in al,0x71                         ;读RTC当前时间(秒)
      push ax

      mov al,2
      or al,0x80
      out 0x70,al
      in al,0x71                         ;读RTC当前时间(分)
      push ax

      mov al,4
      or al,0x80
      out 0x70,al
      in al,0x71                         ;读RTC当前时间(时)
      push ax

      mov al,0x0c                        ;寄存器C的索引。且开放NMI 
      out 0x70,al
      in al,0x71                         ;读一下RTC的寄存器C，否则只发生一次中断
                                         ;此处不考虑闹钟和周期性中断的情况 
      mov ax,0xb800
      mov es,ax

      pop ax
      call bcd_to_ascii
      mov bx,12*160 + 36*2               ;从屏幕上的12行36列开始显示

      mov [es:bx],ah
      mov [es:bx+2],al                   ;显示两位小时数字

      mov al,':'
      mov [es:bx+4],al                   ;显示分隔符':'
      not byte [es:bx+5]                 ;反转显示属性 

      pop ax
      call bcd_to_ascii
      mov [es:bx+6],ah
      mov [es:bx+8],al                   ;显示两位分钟数字

      mov al,':'
      mov [es:bx+10],al                  ;显示分隔符':'
      not byte [es:bx+11]                ;反转显示属性

      pop ax
      call bcd_to_ascii
      mov [es:bx+12],ah
      mov [es:bx+14],al                  ;显示两位小时数字
      
      mov al,0x20                        ;中断结束命令EOI 
      out 0xa0,al                        ;向从片发送 
      out 0x20,al                        ;向主片发送 

      pop es
      pop dx
      pop cx
      pop bx
      pop ax

      iret

;-------------------------------------------------------------------------------
bcd_to_ascii:                            ;BCD码转ASCII
                                         ;输入：AL=bcd码
                                         ;输出：AX=ascii
      mov ah,al                          ;分拆成两个数字 
      and al,0x0f                        ;仅保留低4位 
      add al,0x30                        ;转换成ASCII 

      shr ah,4                           ;逻辑右移4位 
      and ah,0x0f                        
      add ah,0x30

      ret

;-------------------------------------------------------------------------------
;程序的入口的偏移地址
start:
        ;初始化栈寄存器，和栈偏移寄存器
      ;处理器执行任何一条改变堆栈寄存器ss的指令时，会在下一条指令执行期间完全禁止中断
      mov ax,[stack_segment]    ;
      ;在这两条指令的执行期间，处理器禁止中断
      mov ss,ax
      mov sp,ss_pointer
      ;在修改栈寄存器指令完成之后，处理器允许中断

      ;更新数据段寄存器
      mov ax,[data_segment]
      mov ds,ax
      
      ;安装中断向量之前
      mov bx,init_msg                    ;显示初始信息 
      call put_string

      mov bx,inst_msg                    ;显示安装信息 
      call put_string
      
      ;为了修改某中断在中断向量表中的登记项，需要先找到他
      mov al,0x70       ;因为rtc连接到的是8259的从片的IRO端口，所以rtc就是代表着0x70号中断
      mov bl,4                  
      mul bl                             ;计算0x70号中断在IVT中的偏移,
      mov bx,ax                           ;计算结果在ax中，ax中就是当前中断在中断向量表中的位置，通过这个位置我们就可以进入到这个中断程序中
        
        ;cli指令就是把中断标志位清空，就是INTR引脚传来的中断信号都被忽略了，
        ;sti设置中断标志位,处理器可以接收和相应中断
        ;因为我们现在要进行中断处理了
      cli                                ;防止改动期间发生新的0x70号中断

        ;中断向量表处于0x0000:0x0000开始
      push es           ;将段寄存器es压栈临时保存
      mov ax,0x0000     ;
      mov es,ax         ;将es指向中断向量表所在的段
      ;每个地址都是1个字大小
      mov word [es:bx],new_int_0x70      ;偏移地址。往中断向量表中写入新的程序偏移地址
                                          
      mov word [es:bx+2],cs              ;段地址    ,写入程序的段地址,就在当前代码段内
      pop es    

        ;接下来就是设置RTC的工作状态，使他能产生中断信号给8259中断控制器
      ;rtc到8259中断控制器的线只有1条，但是它可以产生多种中断：闹钟中断，更新中断，周期中断
      ;每当RTC更新了一次CMOS RAM的时期和时间后就将发起中断，更新周期每秒进行一次，所以该中断也是每秒发生一次
      ;在计算机运行过程中，RTC芯片会周期性地更新CMOS RAM中的日期和时间数据，确保计算机能够始终跟踪准确的时间。
      ;每当更新完成时，RTC芯片会产生一个更新周期结束中断，通知计算机系统日期和时间已经更新。
      
      ;0x70是索引端口，用来指定cmos-ram内的单元，0x71 0x75是数据端口，可以读取相应的数据，
      ;0x70中的最高位用来指定控制NMI的开关，低7位来代表cmos-ram的偏移地址
      mov al,0x0b                        ;RTC寄存器,先指定b寄存器
      ;再设置是否要nmi
      or al,0x80                         ;阻断NMI ,把最高位设置成1,来阻断nmi
      out 0x70,al                       ;把数据写入到0x70端口

      ;处理数据端口0x71
      ;只使用更新后中断
      ;0x12:允许使用24小时制，更新结束后允许中断,禁止周期性中断，禁止闹钟功能
      mov al,0x12                        ;往b寄存器写入0x12,设置寄存器B，禁止周期性中断，开放更 
      out 0x71,al                        ;新结束后中断，BCD码，24小时制 

        ;读取寄存器c的内容，寄存器C是只读的，当中断产生的时候，可以通过这个寄存器来识别中断的原因
      mov al,0x0c
      out 0x70,al
      ;因为如果不读的话，相应的位没有清0，中断就不会发生，无法知道是否出现中断

      in al,0x71                         ;读RTC寄存器C，复位未决的中断状态
        
        ;8259中的中断屏蔽寄存器IMR，8位寄存器，用来决定该引脚来的中断是否能够通过8259送往处理器中

      in al,0xa1                         ;读8259从片的IMR寄存器 选择0xa1,从8259芯片
      ;把第0位清除（rtc连接到IR0）,所以允许中断
      and al,0xfe                        ;清除bit 0(此位连接RTC)
      out 0xa1,al                        ;写回此寄存器 把修改后的数据写回到0xa1从8259寄存器中

      sti                                ;重新开放中断 ，现在中断随时都能出现了

      mov bx,done_msg                    ;显示安装完成信息 
      call put_string

      mov bx,tips_msg                    ;显示提示信息
      call put_string
      
      mov cx,0xb800
      mov ds,cx
      mov byte [12*160 + 33*2],'@'       ;屏幕第12行，35列
       
 .idle:
      hlt                                ;使CPU进入低功耗状态，直到用中断唤醒
      not byte [12*160 + 33*2+1]         ;反转显示属性 
      jmp .idle

;-------------------------------------------------------------------------------
;显示字符串
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
         mov ax,bx                       ; 
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

;===============================================================================
;数据段
SECTION data align=16 vstart=0
        
    init_msg       db 'Starting...',0x0d,0x0a,0         ;初始化中断
                   
    inst_msg       db 'Installing a new interrupt 70H...',0     ;正在安装中断向量
    
    done_msg       db 'Done.',0x0d,0x0a,0

    tips_msg       db 'Clock is now working.',0
                   
;===============================================================================
;栈段
SECTION stack align=16 vstart=0
           
                 resb 256
ss_pointer:
 
;===============================================================================
SECTION program_trail
;程序的大小
program_end: