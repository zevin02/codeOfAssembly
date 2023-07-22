         ;代码清单13-2
         ;文件名：c13_core.asm
         ;文件说明：保护模式微型核心程序 
         ;创建日期：2011-10-26 12:11
       
       ;内核文件还包含了一个头部，记录了各个段的汇编位置，这些数据用来告诉初始化代码怎么加载内核

         ;以下常量定义部分。内核的大部分内容都应当固定 ,声明一些常数,equ是一个伪指令，不会占内存
         core_code_seg_sel     equ  0x38    ;内核代码段选择子
         core_data_seg_sel     equ  0x30    ;内核数据段选择子 
         sys_routine_seg_sel   equ  0x28    ;系统公共例程代码段的选择子 
         video_ram_seg_sel     equ  0x20    ;视频显示缓冲区的段选择子
         core_stack_seg_sel    equ  0x18    ;内核堆栈段选择子
         mem_0_4_gb_seg_sel    equ  0x08    ;整个0-4GB内存的段的选择子

;-------------------------------------------------------------------------------
         ;以下是系统核心的头部，用于加载核心程序 
         core_length      dd core_end       ;核心程序总长度#00,记录整个内核的大小

         sys_routine_seg  dd section.sys_routine.start
                                            ;系统公用例程段位置#04

         core_data_seg    dd section.core_data.start
                                            ;核心数据段位置#08

         core_code_seg    dd section.core_code.start
                                            ;核心代码段位置#0c

       ;核心代码的入口
         core_entry       dd start          ;核心代码段入口点#10，偏移地址,传送到eip中
                          dw core_code_seg_sel ;段选择子，填充的是刚刚定一个core_code_seg_sel=0x38

;===============================================================================
         [bits 32]
;===============================================================================
SECTION sys_routine vstart=0                ;系统公共例程代码段 
;内核一些api，用于提供各种用途，功能低子过程来简化代码低编写，这些既可以给内核，也可以给用户
;-------------------------------------------------------------------------------
         ;字符串显示例程
put_string:                                 ;显示0终止的字符串并移动光标 
                                            ;输入：DS:EBX=串地址
         push ecx
  .getc:
         mov cl,[ebx];因为ds已经被我们处理好了，所以走到这里ds保持不变,
         or cl,cl
         jz .exit
         call put_char             ;调用这个来进行打印
         inc ebx
         jmp .getc

  .exit:
         pop ecx
         retf                               ;段间返回,会返回段选择子和偏移量

;-------------------------------------------------------------------------------
put_char:                                   ;在当前光标处显示一个字符,并推进
                                            ;光标。仅用于段内调用 
                                            ;输入：CL=字符ASCII码 
         pushad

         ;以下取当前光标位置
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         inc dx                             ;0x3d5
         in al,dx                           ;高字
         mov ah,al

         dec dx                             ;0x3d4
         mov al,0x0f
         out dx,al
         inc dx                             ;0x3d5
         in al,dx                           ;低字
         mov bx,ax                          ;BX=代表光标位置的16位数

         cmp cl,0x0d                        ;回车符？
         jnz .put_0a
         mov ax,bx
         mov bl,80
         div bl
         mul bl
         mov bx,ax
         jmp .set_cursor

  .put_0a:
         cmp cl,0x0a                        ;换行符？
         jnz .put_other
         add bx,80
         jmp .roll_screen

  .put_other:                               ;正常显示字符
         push es
         mov eax,video_ram_seg_sel          ;0xb8000段的选择子
         mov es,eax
         shl bx,1
         mov [es:bx],cl
         pop es

         ;以下将光标位置推进一个字符
         shr bx,1
         inc bx

  .roll_screen:
         cmp bx,2000                        ;光标超出屏幕？滚屏
         jl .set_cursor

         push ds
         push es
         mov eax,video_ram_seg_sel
         mov ds,eax
         mov es,eax
         cld
         mov esi,0xa0                       ;小心！32位模式下movsb/w/d 
         mov edi,0x00                       ;使用的是esi/edi/ecx 
         mov ecx,1920
         ;在32位下，是把数据从DS:ESI传输到ES:DSI
         rep movsd                        ;movsd用来在两个内存区域之间进行传输双字的数据，
         mov bx,3840                        ;清除屏幕最底一行
         mov ecx,80                         ;32位程序应该使用ECX
  .cls:
         mov word[es:bx],0x0720
         add bx,2
         loop .cls

         pop es
         pop ds

         mov bx,1920

  .set_cursor:
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         inc dx                             ;0x3d5
         mov al,bh
         out dx,al
         dec dx                             ;0x3d4
         mov al,0x0f
         out dx,al
         inc dx                             ;0x3d5
         mov al,bl
         out dx,al

         popad
         ret                                

;-------------------------------------------------------------------------------
read_hard_disk_0:                           ;从硬盘读取一个逻辑扇区
                                            ;EAX=逻辑扇区号
                                            ;DS:EBX=目标缓冲区地址
                                            ;返回：EBX=EBX+512
         push eax 
         push ecx
         push edx
      
         push eax
         
         mov dx,0x1f2
         mov al,1
         out dx,al                          ;读取的扇区数

         inc dx                             ;0x1f3
         pop eax
         out dx,al                          ;LBA地址7~0

         inc dx                             ;0x1f4
         mov cl,8
         shr eax,cl
         out dx,al                          ;LBA地址15~8

         inc dx                             ;0x1f5
         shr eax,cl
         out dx,al                          ;LBA地址23~16

         inc dx                             ;0x1f6
         shr eax,cl
         or al,0xe0                         ;第一硬盘  LBA地址27~24
         out dx,al

         inc dx                             ;0x1f7
         mov al,0x20                        ;读命令
         out dx,al

  .waits:
         in al,dx
         and al,0x88
         cmp al,0x08
         jnz .waits                         ;不忙，且硬盘已准备好数据传输 

         mov ecx,256                        ;总共要读取的字数
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         retf                               ;段间返回 

;-------------------------------------------------------------------------------
;汇编语言程序是极难一次成功，而且调试非常困难。这个例程可以提供帮助 
put_hex_dword:                              ;在当前光标处以十六进制形式显示
                                            ;一个双字并推进光标 
                                            ;输入：EDX=要转换并显示的数字
                                            ;输出：无
         pushad
         push ds
      
         mov ax,core_data_seg_sel           ;切换到核心数据段 
         mov ds,ax
      
         mov ebx,bin_hex                    ;指向核心数据段内的转换表
         mov ecx,8
  .xlt:    
         rol edx,4
         mov eax,edx
         and eax,0x0000000f
         xlat
      
         push ecx
         mov cl,al                           
         call put_char
         pop ecx
       
         loop .xlt
      
         pop ds
         popad
         retf
      
;-------------------------------------------------------------------------------
;动态分配内存
allocate_memory:                            ;分配内存
                                            ;输入：ECX=希望分配的字节数
                                            ;输出：ECX=起始线性地址 
         push ds
         push eax
         push ebx
         ;先让段寄存器指向数据单元
         mov eax,core_data_seg_sel
         mov ds,eax
      
         mov eax,[ram_alloc]              ;获得ram_alloc中的值
         ;ecx中就是西完分配的内存大小
         add eax,ecx                        ;下一次分配时的起始地址
         ;原则上西完把eax的值写回到ram_alloc单元中，但是最好是4字节对齐
      
         ;这里应当有检测可用内存数量的指令
          
         mov ecx,[ram_alloc]                ;返回分配的起始地址

       ;最好把他变成4字节对齐
         mov ebx,eax
         and ebx,0xfffffffc
         add ebx,4                          ;强制对齐 ebx的值就是4字节对齐的位置处
         ;检查eax是否已经是4字节对齐
         test eax,0x00000003                ;下次分配的起始地址最好是4字节对齐
         cmovnz eax,ebx                     ;如果没有对齐，则强制对齐 
         mov [ram_alloc],eax                ;下次从该地址分配内存
                                            ;cmovcc指令可以避免控制转移 
         pop ebx
         pop eax
         pop ds

         retf        ;只能使用远过程来调用

;-------------------------------------------------------------------------------
set_up_gdt_descriptor:                      ;在GDT内安装一个新的描述符
                                            ;输入：EDX:EAX=描述符 
                                            ;输出：CX=描述符的选择子
         push eax
         push ebx
         push edx
      
         push ds
         push es
      
         mov ebx,core_data_seg_sel          ;切换到核心数据段
         mov ds,ebx
         ;sgdt可以将GDTR寄存器的基地址和边界数据保存到指定的内存位置
         ;pgdt是一个6字节的内存位置
         sgdt [pgdt]                        ;以便开始处理GDT

       
         mov ebx,mem_0_4_gb_seg_sel
         mov es,ebx  ;

       ;安装描述符到指定的位置
         movzx ebx,word [pgdt]              ;GDT界限 ，我们知道GDT的界限值是16位，由于构造线性地址add需要使用两个相同的32位寄存器,前面用0填充
         inc bx                             ;GDT总字节数，也是下一个描述符偏移 

         add ebx,[pgdt+2]                   ;下一个描述符的线性地址 
         ;ebx就是下一个描述符的地址

         mov [es:ebx],eax          ;把低16位安装
         mov [es:ebx+4],edx        ;安装高16位
      
         add word [pgdt],8                  ;增加一个描述符的大小   
      
         lgdt [pgdt]                        ;对GDT的更改生效 
              
       ;根据GDT的新界限值生成相应的段选择子


         mov ax,[pgdt]                      ;得到GDT界限值
         xor dx,dx
         mov bx,8
         div bx                             ;除以8，去掉余数
         ;商就是我们需要的描述符号eax中
         mov cx,ax                          
         shl cx,3                           ;将索引号移到正确位置 左移3位
         ;TI=0指向GDT，rpl=00，0特权级

         pop es
         pop ds

         pop edx
         pop ebx
         pop eax
      
         retf        ;返回
;-------------------------------------------------------------------------------
make_seg_descriptor:                        ;构造存储器和系统的段描述符
                                            ;输入：EAX=线性基地址
                                            ;      EBX=段界限
                                            ;      ECX=属性。各属性位都在原始
                                            ;          位置，无关的位清零 
                                            ;返回：EDX:EAX=描述符
         mov edx,eax
         shl eax,16
         or ax,bx                           ;描述符前32位(EAX)构造完毕

         and edx,0xffff0000                 ;清除基地址中无关的位
         rol edx,8
         bswap edx                          ;装配基址的31~24和23~16  (80486+)

         xor bx,bx
         or edx,ebx                         ;装配段界限的高4位

         or edx,ecx                         ;装配属性

         retf

;===============================================================================
SECTION core_data vstart=0                  ;系统核心的数据段
;内核数据段，提供了一个可读写低内存空间，给内核自己使用 
;-------------------------------------------------------------------------------
         pgdt             dw  0             ;用于设置和修改GDT 
                          dd  0

         ram_alloc        dd  0x00100000    ;下次分配内存时的起始内存地址

         
         ;符号地址检索表

         salt:
              ;内核的salt表是静态的，所有要加载的用户程序都能使用，所以这个肯定比用户的salt大

              ;262字节来表示一个条目
         salt_1           db  '@PrintString'
                     times 256-($-salt_1) db 0   ;256字节的条目用来存储符号名
                     ;6字节来填写程序的入口
                          dd  put_string         ;4字节的偏移地址
                          dw  sys_routine_seg_sel       ;2字节的段选择子

         salt_2           db  '@ReadDiskData'
                     times 256-($-salt_2) db 0
                          dd  read_hard_disk_0
                          dw  sys_routine_seg_sel

         salt_3           db  '@PrintDwordAsHexString'
                     times 256-($-salt_3) db 0
                          dd  put_hex_dword
                          dw  sys_routine_seg_sel


              ;用户调用这个程序，说明用户程序结束，把控制返回给内核
         salt_4           db  '@TerminateProgram'
                     times 256-($-salt_4) db 0
                          dd  return_point
                          dw  core_code_seg_sel

         salt_item_len   equ $-salt_4
         salt_items      equ ($-salt)/salt_item_len

         message_1        db  '  If you seen this message,that means we '
                          db  'are now in protect mode,and the system '
                          db  'core is loaded,and the video display '
                          db  'routine works perfectly.',0x0d,0x0a,0

         message_5        db  '  Loading user program...',0
         
         do_status        db  'Done.',0x0d,0x0a,0
         
         message_6        db  0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                          db  '  User program terminated,control returned.',0

         bin_hex          db '0123456789ABCDEF'
                                            ;put_hex_dword子过程用的查找表 
         core_buf   times 2048 db 0         ;内核用的缓冲区

         esp_pointer      dd 0              ;内核用来临时保存自己的栈指针     

         cpu_brnd0        db 0x0d,0x0a,'  ',0    ;打印品牌信息，先留出空行
         cpu_brand  times 52 db 0
         cpu_brnd1        db 0x0d,0x0a,0x0d,0x0a,0      

;===============================================================================
SECTION core_code vstart=0
;内核代码和数据,用于分配内存，读取和加载用户程序,控制用户程序低执行
;-------------------------------------------------------------------------------
;加载用户程序被定义成为了一个函数，这样就能反复调用
load_relocate_program:                      ;加载并重定位用户程序
                                            ;输入：ESI=起始逻辑扇区号
                                            ;返回：AX=指向用户程序头部的选择子 
         push ebx
         push ecx
         push edx
         push esi
         push edi
      
         push ds
         push es
      
         mov eax,core_data_seg_sel
         mov ds,eax                         ;切换DS到内核数据段
       
         mov eax,esi                        ;读取程序头部数据 
         mov ebx,core_buf                   ;数据存放的地点是我们预先开辟的内核缓存区    
         call sys_routine_seg_sel:read_hard_disk_0
         ;数据填充完毕
         ;以下判断整个程序有多大
         mov eax,[core_buf]                 ;程序尺寸
         mov ebx,eax
         ;我们发现512的倍数，低9bit都是0
         and ebx,0xfffffe00                 ;使之512字节对齐（能被512整除的数， 
         ;先变成一个512的倍数
         add ebx,512                        ;低9位都为0 ，再加上512字节
         ;测试eax低9位，如果测试的结果不全为0,就使用凑的结果
         test eax,0x000001ff                ;程序的大小正好是512的倍数吗? 
        
         cmovnz eax,ebx                     ;不是。使用凑整的结果 
      
       ;接下来就是把用户程序从硬盘上读取到内存中
         mov ecx,eax                        ;实际需要申请的内存数量,需要申请的数量就是我们读取的大小，因为我们前面读取的第一个扇区是在缓存区中
         call sys_routine_seg_sel:allocate_memory
         ;ecx中就是申请到的内存地址

         mov ebx,ecx                        ;ebx -> 申请到的内存首地址,目的就是做为从硬盘上加载整个程序的起始地址
         
         push ebx                           ;保存该首地址 ,将这个地址压栈，目的是为了之后来访问用户程序的头部

         xor edx,edx
         mov ecx,512
         div ecx
         mov ecx,eax                        ;总扇区数 ,控制循环的次数
      
         mov eax,mem_0_4_gb_seg_sel         ;切换DS到0-4GB的段
         mov ds,eax

         mov eax,esi                        ;起始扇区号 
  .b1:
       ;读取用户程序到内存中
         call sys_routine_seg_sel:read_hard_disk_0
         inc eax
         loop .b1                           ;循环读，直到读完整个用户程序

       ;现在所有用户程序都已经读取到了内存中,就需要根据头部信息来创建段描述符

         ;建立程序头部段描述符
         pop edi                            ;恢复程序装载的首地址 
         ;edi现在是该程序的起始地址

         ;构造程序头部段的描述符
         mov eax,edi                        ;程序头部起始线性地址
         mov ebx,[edi+0x04]                 ;段长度
         dec ebx                            ;段界限 
         mov ecx,0x00409200                 ;字节粒度的数据段描述符
         call sys_routine_seg_sel:make_seg_descriptor   ;过程 返回edx:eax64位的段描述符
         ;将描述符安装到GDT中
         call sys_routine_seg_sel:set_up_gdt_descriptor
         mov [edi+0x04],cx                   ;把这个段选择子写回到用户程序的头部

         ;建立程序代码段描述符
         mov eax,edi
         add eax,[edi+0x14]                 ;代码起始线性地址
         mov ebx,[edi+0x18]                 ;段长度
         dec ebx                            ;段界限
         mov ecx,0x00409800                 ;字节粒度的代码段描述符
         call sys_routine_seg_sel:make_seg_descriptor
         call sys_routine_seg_sel:set_up_gdt_descriptor
         mov [edi+0x14],cx         ;把这个代码段的选择子写回到内存供使用

         ;建立程序数据段描述符
         mov eax,edi
         add eax,[edi+0x1c]                 ;数据段起始线性地址
         mov ebx,[edi+0x20]                 ;段长度
         dec ebx                            ;段界限
         mov ecx,0x00409200                 ;字节粒度的数据段描述符
         call sys_routine_seg_sel:make_seg_descriptor
         call sys_routine_seg_sel:set_up_gdt_descriptor
         mov [edi+0x1c],cx

         ;建立程序堆栈段描述符,堆栈所使用的空间不需要用户程序提供，而是由内核来进行动态分配
         mov ecx,[edi+0x0c]                 ;4KB的倍率 
         mov ebx,0x000fffff
         sub ebx,ecx                        ;得到段界限
         mov eax,4096                        
         mul dword [edi+0x0c]               ;用4096乘倍率,得到相应堆栈大小

         mov ecx,eax                        ;准备为堆栈分配内存 
         call sys_routine_seg_sel:allocate_memory
         add eax,ecx                        ;得到堆栈的高端物理地址 
         mov ecx,0x00c09600                 ;4KB粒度的堆栈段描述符
         call sys_routine_seg_sel:make_seg_descriptor
         call sys_routine_seg_sel:set_up_gdt_descriptor
         mov [edi+0x08],cx                ;把构造好的堆栈段选择子写回


         ;重定位SALT
         ;用户程序加载的时候，内核根据这些符号名来填写他们的入口地址
         ;内核也需要创建一个SALT表
         mov eax,[edi+0x04]
         mov es,eax                         ;es -> 用户程序头部,这个已经是我们填写好的头部选择子 
         mov eax,core_data_seg_sel
         mov ds,eax                       ;ds数据段选择子
      
         cld         ;把direction清空，表示正向扩展

       ;使用ds:esi指向CORE-SALT
       ;使用es:edi指向User-SALT

         mov ecx,[es:0x24]                  ;用户程序的SALT条目数
         mov edi,0x28                       ;用户程序内的SALT位于头部内0x2c处
        ;遍历U-salt和COre的每一项一一比较
  .b2: 
         push ecx
         push edi
      
         mov ecx,salt_items        ;将内核的条目数取出来，用来循环一一比较
         mov esi,salt              ;要比较的内核地址
  .b3:
         push edi
         push esi
         push ecx

       ;这个就是核心过程
         mov ecx,64                         ;检索表中，每条目的比较次数 由于每个条目256字节/4=64次
         ;
         repe cmpsd                         ;每次比较4字节,如果两个字符串相符合，就连续比对64次
         ;在比对结束的时候，zf=1.如果两个字符串不相等，中间就结束了
         jnz .b4;如果zf=0,说明不相等，直接开始下一次内循环
       
         ;zf=1说明两个字符串相等，匹配上了
         ;现在的任务就是把core-salt传送到u-salt条目的开始部分,头部的6字节改成了入口地址
         
         mov eax,[esi]                      ;若匹配，esi恰好指向其后的地址数据,eax中的4个字节就是入口地址
         mov [es:edi-256],eax               ;将字符串改写成偏移地址 ,修改成偏移地址
         mov ax,[esi+4]                     ;两个字节的段选择子
         mov [es:edi-252],ax                ;以及段选择子
  .b4:
      

         pop ecx
         pop esi
         add esi,salt_item_len            ;esi加上262字节，指向下一个条目
         pop edi                            ;从头比较 
         loop .b3                         ;内循环
      
         
         ;从栈顶取出来
         pop edi
         add edi,256 ;指向下一个条目,进行比较
         pop ecx
         loop .b2    ;外循环

         mov ax,[es:0x04]          ;把头部的段选择子放到ax寄存器中

         pop es                             ;恢复到调用此过程前的es段 
         pop ds                             ;恢复到调用此过程前的ds段
      
         pop edi
         pop esi
         pop edx
         pop ecx
         pop ebx
      
         ret
      
;-------------------------------------------------------------------------------
start:
         mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
         mov ds,ecx

         mov ebx,message_1         ;因为ds指向了数据段，所以可以使用其中的标号
         ;这个字符串是一个远转移，指令中给出了段选择子和段内偏移量
         call sys_routine_seg_sel:put_string ;调用打印函数来显示一个字符串
                                         
         ;显示处理器品牌信息 
         ;处理器内部包含了大量低秘密，处理器的型号，高速缓存的数量，是否具备温度，电源管理功能
         ;逻辑处理器的数量，高级可编程中断处理器的类型，线性地址的宽度，是否具有多媒体扩展，单指令多数据指令
         
         ;要返回品牌信息，使用0x800000002-0x80000004号功能，分3次进行
         ;正常是先使用0号功能来进行
         mov eax,0x80000002;eax中用来指定要用来返回什么样的功能
         ;cpuid指令可以放回处理器的标识和特性信息，处理器将把信息放到eax,ebx,ecx,或者edx
         cpuid
         mov [cpu_brand + 0x00],eax       ;执行的结果依次保存在cpu_brand开辟的52个字节的空间中
         mov [cpu_brand + 0x04],ebx
         mov [cpu_brand + 0x08],ecx
         mov [cpu_brand + 0x0c],edx
      
         mov eax,0x80000003
         cpuid
         mov [cpu_brand + 0x10],eax
         mov [cpu_brand + 0x14],ebx
         mov [cpu_brand + 0x18],ecx
         mov [cpu_brand + 0x1c],edx

         mov eax,0x80000004
         cpuid
         mov [cpu_brand + 0x20],eax
         mov [cpu_brand + 0x24],ebx
         mov [cpu_brand + 0x28],ecx
         mov [cpu_brand + 0x2c],edx

         mov ebx,cpu_brnd0
         call sys_routine_seg_sel:put_string     ;把这个空行进行打印
         mov ebx,cpu_brand
         call sys_routine_seg_sel:put_string     ;打印品牌信息
         mov ebx,cpu_brnd1
         call sys_routine_seg_sel:put_string     ;再留空

       ;开始加载用户程序
         mov ebx,message_5
         call sys_routine_seg_sel:put_string
         
         ;内核的主要任务就是加载和执行用户程序，这个工作是会反复进行的，一般来说这个需要定义成一个函数
         mov esi,50                          ;用户程序位于逻辑50扇区 
         call load_relocate_program
      
         
         ;显示信息
         mov ebx,do_status
         call sys_routine_seg_sel:put_string
      
         ;进入用户程序后，用户程序切换到自己的堆栈,从用户程序返回的时候，还要从这个位置恢复内核堆栈指针
         mov [esp_pointer],esp               ;临时保存堆栈指针
       
         mov ds,ax                        ;使段寄存器指向用户程序的头部
      
         jmp far [0x10]                      ;控制权交给用户程序（入口点）
                                             ;堆栈可能切换 

return_point:                                ;用户程序返回点
         mov eax,core_data_seg_sel           ;使ds指向核心数据段
         mov ds,eax

         mov eax,core_stack_seg_sel          ;切换回内核自己的堆栈
         mov ss,eax 
         mov esp,[esp_pointer]

         mov ebx,message_6
         call sys_routine_seg_sel:put_string

         ;这里可以放置清除用户程序各种描述符的指令
         ;也可以加载并启动其它程序
       
         hlt
            
;===============================================================================
SECTION core_trail
;-------------------------------------------------------------------------------
core_end: