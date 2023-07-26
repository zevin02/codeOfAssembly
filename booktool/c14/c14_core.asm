         ;代码清单14-1
         ;文件名：c14_core.asm
         ;文件说明：保护模式微型核心程序 
         ;创建日期：2011-11-6 18:37

         ;以下常量定义部分。内核的大部分内容都应当固定 
         core_code_seg_sel     equ  0x38    ;内核代码段选择子
         core_data_seg_sel     equ  0x30    ;内核数据段选择子 
         sys_routine_seg_sel   equ  0x28    ;系统公共例程代码段的选择子 
         video_ram_seg_sel     equ  0x20    ;视频显示缓冲区的段选择子
         core_stack_seg_sel    equ  0x18    ;内核堆栈段选择子
         mem_0_4_gb_seg_sel    equ  0x08    ;整个0-4GB内存的段的选择子

;-------------------------------------------------------------------------------
         ;以下是系统核心的头部，用于加载核心程序 
         core_length      dd core_end       ;核心程序总长度#00

         sys_routine_seg  dd section.sys_routine.start
                                            ;系统公用例程段位置#04

         core_data_seg    dd section.core_data.start
                                            ;核心数据段位置#08

         core_code_seg    dd section.core_code.start
                                            ;核心代码段位置#0c


         core_entry       dd start          ;核心代码段入口点#10
                          dw core_code_seg_sel

;===============================================================================
         [bits 32]
;===============================================================================
SECTION sys_routine vstart=0                ;系统公共例程代码段 
;-------------------------------------------------------------------------------
         ;字符串显示例程
put_string:                                 ;显示0终止的字符串并移动光标 
                                            ;输入：DS:EBX=串地址
         push ecx
  .getc:
         mov cl,[ebx]
         or cl,cl
         jz .exit
         call put_char
         inc ebx
         jmp .getc

  .exit:
         pop ecx
         retf                               ;段间返回

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
         rep movsd
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
allocate_memory:                            ;分配内存
                                            ;输入：ECX=希望分配的字节数
                                            ;输出：ECX=起始线性地址 
         push ds
         push eax
         push ebx
      
         mov eax,core_data_seg_sel
         mov ds,eax
      
         mov eax,[ram_alloc]
         add eax,ecx                        ;下一次分配时的起始地址
      
         ;这里应当有检测可用内存数量的指令
          
         mov ecx,[ram_alloc]                ;返回分配的起始地址

         mov ebx,eax
         and ebx,0xfffffffc
         add ebx,4                          ;强制对齐 
         test eax,0x00000003                ;下次分配的起始地址最好是4字节对齐
         cmovnz eax,ebx                     ;如果没有对齐，则强制对齐 
         mov [ram_alloc],eax                ;下次从该地址分配内存
                                            ;cmovcc指令可以避免控制转移 
         pop ebx
         pop eax
         pop ds

         retf

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

         sgdt [pgdt]                        ;以便开始处理GDT

         mov ebx,mem_0_4_gb_seg_sel
         mov es,ebx

         movzx ebx,word [pgdt]              ;GDT界限
         inc bx                             ;GDT总字节数，也是下一个描述符偏移
         add ebx,[pgdt+2]                   ;下一个描述符的线性地址

         mov [es:ebx],eax
         mov [es:ebx+4],edx

         add word [pgdt],8                  ;增加一个描述符的大小

         lgdt [pgdt]                        ;对GDT的更改生效

         mov ax,[pgdt]                      ;得到GDT界限值
         xor dx,dx
         mov bx,8
         div bx                             ;除以8，去掉余数
         mov cx,ax                          ;获得这个调用门的索引号,
         shl cx,3                           ;将索引号移到正确位置
       ;调用门的选择子也是前面13位是这个调用门在GDT中的索引号
         pop es
         pop ds

         pop edx
         pop ebx
         pop eax

         retf
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

;-------------------------------------------------------------------------------
make_gate_descriptor:                       ;构造门的描述符（调用门等）
                                            ;输入：EAX=门代码在段内偏移地址
                                            ;       BX=门代码所在段的选择子 
                                            ;       CX=段类型及属性等（各属
                                            ;          性位都在原始位置）
                                            ;返回：EDX:EAX=完整的描述符
         push ebx
         push ecx
      
         mov edx,eax                      ;现在edx中赋值32位偏移地址
         and edx,0xffff0000                 ;得到偏移地址高16位 
         or dx,cx                           ;组装属性部分到EDX
         ;edx高32位组装完成
       
         and eax,0x0000ffff                 ;得到偏移地址低16位 
         shl ebx,16                          ;把bx中的段选择子移动到高16位中
         or eax,ebx                         ;组装段选择子部分
         ;现在eax中是低32位就组装好了
      
         pop ecx
         pop ebx
      
         retf                                   
                             
sys_routine_end:

;===============================================================================
SECTION core_data vstart=0                  ;系统核心的数据段 
;------------------------------------------------------------------------------- 
         pgdt             dw  0             ;用于设置和修改GDT 
                          dd  0

         ram_alloc        dd  0x00100000    ;下次分配内存时的起始地址

         ;符号地址检索表，起始偏移地址
         salt:
         salt_1           db  '@PrintString'
                     times 256-($-salt_1) db 0
                          dd  put_string
                          dw  sys_routine_seg_sel

         salt_2           db  '@ReadDiskData'
                     times 256-($-salt_2) db 0
                          dd  read_hard_disk_0
                          dw  sys_routine_seg_sel

         salt_3           db  '@PrintDwordAsHexString'
                     times 256-($-salt_3) db 0
                          dd  put_hex_dword
                          dw  sys_routine_seg_sel

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

         message_2        db  '  System wide CALL-GATE mounted.',0x0d,0x0a,0
         
         message_3        db  0x0d,0x0a,'  Loading user program...',0
         
         do_status        db  'Done.',0x0d,0x0a,0
         
         message_6        db  0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                          db  '  User program terminated,control returned.',0

         bin_hex          db '0123456789ABCDEF'
                                            ;put_hex_dword子过程用的查找表 

         core_buf   times 2048 db 0         ;内核用的缓冲区

         esp_pointer      dd 0              ;内核用来临时保存自己的栈指针     

         cpu_brnd0        db 0x0d,0x0a,'  ',0
         cpu_brand  times 52 db 0
         cpu_brnd1        db 0x0d,0x0a,0x0d,0x0a,0

         ;任务控制块链
         ;初始化了一个双子，初始的值=0.说明当前还没有任务
         ;创建一个任务之后，第一个任务的TCB 的线性地址就要写入到这个地方，方便链表串连起来,可以依次找到每个任务
         tcb_chain        dd  0

core_data_end:
               
;===============================================================================
SECTION core_code vstart=0
;-------------------------------------------------------------------------------
fill_descriptor_in_ldt:                     ;在LDT内安装一个新的描述符
                                            ;输入：EDX:EAX=描述符
                                            ;          EBX=TCB基地址
                                            ;输出：CX=描述符的选择子
         push eax
         push edx
         push edi
         push ds

         mov ecx,mem_0_4_gb_seg_sel
         mov ds,ecx
       ;访问TCB，获得LDT的基地址
         mov edi,[ebx+0x0c]                 ;获得LDT基地址
         
         xor ecx,ecx
         mov cx,[ebx+0x0a]                  ;获得LDT界限，16位

         inc cx                             ;LDT的总字节数，即新描述符偏移地址
         

         mov [edi+ecx+0x00],eax    ;低16位
         mov [edi+ecx+0x04],edx    ;高16位       ;安装描述符

         add cx,8                           ;总字节数+8,更新
         dec cx                             ;得到新的LDT界限值 

         mov [ebx+0x0a],cx                  ;更新LDT界限值到TCB
         ;构造段选择子

         mov ax,cx
         xor dx,dx
         mov cx,8
         div cx
       ;ax中就是相应的在LDT中的索引号
         mov cx,ax
         shl cx,3                           ;左移3位，并且

         or cx,0000_0000_0000_0100B         ;使TI位=1，指向LDT，最后使RPL=00 
         ;返回cx段选择子

         pop ds
         pop edi
         pop edx
         pop eax
     
         ret
      
;------------------------------------------------------------------------------- 
load_relocate_program:                      ;加载并重定位用户程序
                                            ;输入: PUSH 逻辑扇区号
                                            ;      PUSH 任务控制块基地址
                                            ;输出：无 
         ;因为是call调用的，栈的这个位置就是返回的地址
         pushad      ;先保护现场,把所有的通用寄存器压栈（包括了ebp的原始内容）
      
      ;压入段寄存器，要将这些段寄存器零扩展到32位，高16位全零，然后将esp-4,处栈的时候，就会把这个32位截断成16位pop
         push ds
         push es
       ;栈的访问1.使用esp先进后出，2.像数据段一样访问,这种访问需要使用ebp
       ;mov edx [ebp],从栈中读取一个双字，ss:ebp，默认使用ss段选择子
         mov ebp,esp                        ;为访问通过堆栈传递的参数做准备

      
         mov ecx,mem_0_4_gb_seg_sel
         mov es,ecx  ;es指向了4G的内存大小
      
         mov esi,[ebp+11*4]                 ;从堆栈中取得TCB的基地址         
        ;用户程序的代码段和数据段必须使用描述符来引用，放在LDT中，GDT是存放任务共有的描述符，比如共有数据段和历程

       ;每个任务都可以有自己的LDT，在内存的任务位置
       ;1.分配一个内存，给LDT使用，为创建用户程序各个段的描述符做准备
       ;2.将LDT的大小和起始位置记录在TCB中
       ;3.分配内存并加载用户程序，将他的大小和起始位置记录在TCB中

         ;以下申请创建LDT所需要的内存
         mov ecx,160                        ;允许安装20个LDT描述符,申请160字节的内存空间来安装LDT

         call sys_routine_seg_sel:allocate_memory
       ;ecx现在是LDT的起始位置
         mov [es:esi+0x0c],ecx              ;登记LDT基地址到TCB中
         ;ldtr contain 48bit,32bit for the ldt address ,the other 16bit for the size-1
         ;因为我们现在是总字节数是0,0-1=0xffff(16bit)
         mov word [es:esi+0x0a],0xffff      ;登记LDT初始的界限到TCB中

         ;以下开始加载用户程序 
         mov eax,core_data_seg_sel
         mov ds,eax                         ;切换DS到内核数据段
       
         mov eax,[ebp+12*4]                 ;从堆栈中取出用户程序起始扇区号, 
         mov ebx,core_buf                   ;读取程序头部数据     
         call sys_routine_seg_sel:read_hard_disk_0


         ;以下判断整个程序有多大,把读取的程序头部存放在内核缓冲区中
         mov eax,[core_buf]                 ;程序尺寸
         mov ebx,eax
         and ebx,0xfffffe00                 ;使eax之512字节对齐（能被512整除的数低 
         add ebx,512                        ;9位都为0 
         test eax,0x000001ff                ;程序的大小正好是512的倍数吗? 
         cmovnz eax,ebx                     ;不是。使用凑整的结果
      
         mov ecx,eax                        ;ecx实际需要申请的内存数量
         call sys_routine_seg_sel:allocate_memory
         mov [es:esi+0x06],ecx              ;把程序加载的基地址记录到TCB中
      
         mov ebx,ecx                        ;ebx -> 申请到的内存首地址
         xor edx,edx
         mov ecx,512
         div ecx
         mov ecx,eax                        ;总扇区数 
      
         mov eax,mem_0_4_gb_seg_sel         ;切换DS到0-4GB的段
         mov ds,eax

         mov eax,[ebp+12*4]                 ;起始扇区号 
  .b1:
         call sys_routine_seg_sel:read_hard_disk_0
         inc eax
         loop .b1                           ;循环读，直到读完整个用户程序


       ;用户程序已经加载到内存中了，现在就可以给LDT中创建段描述符了

         mov edi,[es:esi+0x06]              ;从TCB中获得用户程序的起始地址,

         ;建立用户程序头部段head描述符
         mov eax,edi                        ;程序头部起始线性地址
         mov ebx,[edi+0x04]                 ;段长度
         dec ebx                            ;段界限
         mov ecx,0x0040f200                 ;字节粒度的数据段描述符，特权级3 ，type=0010可读可写的数据段描述符
         call sys_routine_seg_sel:make_seg_descriptor
         ;edx:eax就是构造好的描述符

         ;安装头部段描述符到LDT中 
         ;esi中就是tcb的线性基地址
         mov ebx,esi                        ;TCB的基地址
         call fill_descriptor_in_ldt      ;安装描述符到LDT中

         or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3,RPL=3
         ;通常请求这些段的时候，请求者都是用户自己，所以在LDT中的描述符都是用户自己使用
         mov [es:esi+0x44],cx               ;登记程序头部段选择子到TCB (用户程序的第一个段选择子)
         mov [edi+0x04],cx                  ;把这个段选择子放到用户程序的头部
      
         ;建立程序代码段描述符
         mov eax,edi
         add eax,[edi+0x14]                 ;代码起始线性地址
         mov ebx,[edi+0x18]                 ;段长度
         dec ebx                            ;段界限
         mov ecx,0x0040f800                 ;字节粒度的代码段描述符，特权级3
         call sys_routine_seg_sel:make_seg_descriptor
         mov ebx,esi                        ;TCB的基地址
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
         mov [edi+0x14],cx                  ;登记代码段选择子到用户程序头部的code标号处

         ;建立程序数据段描述符
         mov eax,edi
         add eax,[edi+0x1c]                 ;数据段起始线性地址
         mov ebx,[edi+0x20]                 ;段长度
         dec ebx                            ;段界限 
         mov ecx,0x0040f200                 ;字节粒度的数据段描述符，特权级3
         call sys_routine_seg_sel:make_seg_descriptor
         mov ebx,esi                        ;TCB的基地址
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
         mov [edi+0x1c],cx                  ;登记数据段选择子到头部

         ;建立程序堆栈段描述符
         mov ecx,[edi+0x0c]                 ;4KB的倍率 
         mov ebx,0x000fffff
         sub ebx,ecx                        ;得到段界限
         mov eax,4096                        
         mul ecx                         
         mov ecx,eax                        ;准备为堆栈分配内存 
         call sys_routine_seg_sel:allocate_memory
         add eax,ecx                        ;得到堆栈的高端物理地址 
         mov ecx,0x00c0f600                 ;字节粒度的堆栈段描述符，特权级3
         call sys_routine_seg_sel:make_seg_descriptor
         mov ebx,esi                        ;TCB的基地址
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0011B         ;设置选择子的特权级为3
         mov [edi+0x08],cx                  ;登记堆栈段选择子到头部



         ;重定位SALT 
         ;用户程序的各个段在LDT中，已经安装好了，但是还没有生效（还没有加再到LDTR中），所以只能使用4G的段来访问u-salt
         mov eax,mem_0_4_gb_seg_sel         ;这里和前一章不同，头部段描述符
         mov es,eax                         ;已安装，但还没有生效，故只能通
                                            ;过4GB段访问用户程序头部        

         mov eax,core_data_seg_sel        ;内核数据段
         mov ds,eax
      
         cld         ;清空dflag
       

         mov ecx,[es:edi+0x24]              ;U-SALT条目数(通过访问4GB段取得)   
         add edi,0x28                       ;U-SALT在4GB段内的偏移           ,edi现在指向了用户salt表
  .b2: 
         push ecx
         push edi
      
         mov ecx,salt_items
         mov esi,salt              ;内核salt表
  .b3:
         push edi
         push esi
         push ecx

         mov ecx,64                         ;检索表中，每条目的比较次数 
         repe cmpsd                         ;每次比较4字节 
         jnz .b4
         ;esi中的就是这个内核的位置api的段内偏移量
         mov eax,[esi]                      ;若匹配，则esi恰好指向其后的地址
         mov [es:edi-256],eax               ;将用户的salt字符串改写成偏移地址 
         mov ax,[esi+4]                     ;获得调用门的段选择子
         ;在创建这些段选择子的时候，他的RPL=0.当他被赋值到U-salt的时候，就应该改成用户程序的特权级3
         ;因为这个要给用户使用，所以要改成用户的特权级
         or ax,0000000000000011B            ;以用户程序自己的特权级使用调用门
                                            ;故RPL=3 
         mov [es:edi-252],ax                ;回填调用门选择子 
  .b4:
      
         pop ecx
         pop esi
         add esi,salt_item_len
         pop edi                            ;从头比较 
         loop .b3
      
         pop edi
         add edi,256
         pop ecx
         loop .b2


       ;创建0,1,2特权级的栈
       ;通过调用门转移到全局区域的时候，会改变CPL，还要切换到和目标特权级相同的栈，所以需要为每个任务额外定义栈
       ;3特权级就需要额外创建0,1,2，把这些定义在任务自己的LDT中，同时还要记录在TSS中

         mov esi,[ebp+11*4]                 ;从堆栈中取得TCB的基地址

         ;创建0特权级堆栈
         mov ecx,4096                     ;申请0特权级的4kb内存
         mov eax,ecx                        ;为生成堆栈高端地址做准备 
         mov [es:esi+0x1a],ecx            ;先记录以字节为大小的段大小到TSS中

         shr dword [es:esi+0x1a],12         ;登记0特权级堆栈尺寸到TCB，以4kb为单位的段大小

         call sys_routine_seg_sel:allocate_memory

         add eax,ecx                        ;堆栈必须使用高端地址为基地址
         mov [es:esi+0x1e],eax              ;登记0特权级堆栈基地址到TCB 
         mov ebx,0xffffe                    ;段长度（界限）
         mov ecx,0x00c09600                 ;4KB粒度，读写，特权级0
         call sys_routine_seg_sel:make_seg_descriptor
         mov ebx,esi                        ;TCB的基地址
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0000          ;设置选择子的特权级为RPL=0
         mov [es:esi+0x22],cx               ;登记0特权级堆栈选择子到TCB
         mov dword [es:esi+0x24],0          ;登记0特权级堆栈初始ESP到TCB
      
         ;创建1特权级堆栈
         mov ecx,4096
         mov eax,ecx                        ;为生成堆栈高端地址做准备
         mov [es:esi+0x28],ecx
         shr dword [es:esi+0x28],12               ;登记1特权级堆栈尺寸到TCB
         call sys_routine_seg_sel:allocate_memory
         add eax,ecx                        ;堆栈必须使用高端地址为基地址
         mov [es:esi+0x2c],eax              ;登记1特权级堆栈基地址到TCB
         mov ebx,0xffffe                    ;段长度（界限）
         mov ecx,0x00c0b600                 ;4KB粒度，读写，特权级1
         call sys_routine_seg_sel:make_seg_descriptor
         mov ebx,esi                        ;TCB的基地址
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0001          ;设置选择子的特权级为1
         mov [es:esi+0x30],cx               ;登记1特权级堆栈选择子到TCB
         mov dword [es:esi+0x32],0          ;登记1特权级堆栈初始ESP到TCB

         ;创建2特权级堆栈
         mov ecx,4096
         mov eax,ecx                        ;为生成堆栈高端地址做准备
         mov [es:esi+0x36],ecx
         shr dword [es:esi+0x36],12               ;登记2特权级堆栈尺寸到TCB
         call sys_routine_seg_sel:allocate_memory
         add eax,ecx                        ;堆栈必须使用高端地址为基地址
         mov [es:esi+0x3a],ecx              ;登记2特权级堆栈基地址到TCB
         mov ebx,0xffffe                    ;段长度（界限）
         mov ecx,0x00c0d600                 ;4KB粒度，读写，特权级2
         call sys_routine_seg_sel:make_seg_descriptor
         mov ebx,esi                        ;TCB的基地址
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0010          ;设置选择子的特权级为2
         mov [es:esi+0x3e],cx               ;登记2特权级堆栈选择子到TCB
         mov dword [es:esi+0x40],0          ;登记2特权级堆栈初始ESP到TCB
      

         ;现在TSS的所有信息都已经填充好了
         ;由于LDT和GDT都是用来存放各种系统描述符的，但是他们也是内存段，用来管理系统，所以称为系统段
         ;处理器要求在 GDT中安装每个LDT的描述符，要使用的时候，可以使用他们的选择子来访问LDT，将LDT加载到LDTR中

         ;在GDT中登记LDT描述符
         mov eax,[es:esi+0x0c]              ;从TCB中获得LDT的起始线性地址
         movzx ebx,word [es:esi+0x0a]       ;从TCB中获得LDT段界限，并且填充到32位用0
         ;D(B)位对LDT描述符没有意义
         ;AVL,P位和普通段一样
         ;S=0,系统段
         mov ecx,0x00408200                 ;这个LDT描述符的属性，LDT描述符，特权级0

         call sys_routine_seg_sel:make_seg_descriptor

         call sys_routine_seg_sel:set_up_gdt_descriptor
         mov [es:esi+0x10],cx               ;登记LDT选择子到TCB中
       

         ;创建用户程序的TSS
         mov ecx,104                        ;tss的基本尺寸，申请104字节，来创建TSS
         mov [es:esi+0x12],cx               ;把tss的大小先记录到TCB中

         dec word [es:esi+0x12]             ;登记TSS界限值到TCB ，更新界限值,界限值必须是103,任何小于这个值，在这个时候都会导致处理器中断

         call sys_routine_seg_sel:allocate_memory       ;为TSS开辟一个内存地址
         mov [es:esi+0x14],ecx              ;登记TSS的基地址到TCB
      
         ;登记基本的TSS表格内容
         mov word [es:ecx+0],0              ;反向链=0，表示这是唯一一个TSS任务
      
       ;更新0,1,2特权栈的段选择子和他们的栈指针，这些栈信息都在TCB中，可以直接从TCB中获取，再写到TSS中的相应位置中

         mov edx,[es:esi+0x24]              ;登记0特权级堆栈初始ESP0
         mov [es:ecx+4],edx                 ;到TSS中
      
         mov dx,[es:esi+0x22]               ;登记0特权级堆栈段选择子
         mov [es:ecx+8],dx                  ;到TSS中
      
         mov edx,[es:esi+0x32]              ;登记1特权级堆栈初始ESP
         mov [es:ecx+12],edx                ;到TSS中

         mov dx,[es:esi+0x30]               ;登记1特权级堆栈段选择子
         mov [es:ecx+16],dx                 ;到TSS中

         mov edx,[es:esi+0x40]              ;登记2特权级堆栈初始ESP
         mov [es:ecx+20],edx                ;到TSS中

         mov dx,[es:esi+0x3e]               ;登记2特权级堆栈段选择子
         mov [es:ecx+24],dx                 ;到TSS中

       ;将该任务的LDT段选择子从TCB中获得，并填写到TSS中
         mov dx,[es:esi+0x10]               ;登记任务的LDT选择子
         mov [es:ecx+96],dx                 ;到TSS中
      
      ;填写IO许可映射区的地址，TSS的段界限是103,说明没有这个区域
         ;这个IO映射基地址是从TSS的0位位置开始算起，而不是实际的32位物理地址

         mov dx,[es:esi+0x12]               ;登记任务的I/O位图偏移
         mov [es:ecx+102],dx                ;到TSS中，这个地方填写的是103,说明没有IO区域

      

        ;tss中的T位是用来软件调试的，如果T=1，切换任务的时候，就会导致调试异常中断，调试程序可以接管中断显示任务状态，执行调试操作
        ;这里我们设置成0,不需要进行软件调试
         mov word [es:ecx+100],0            ;T=0
       
         ;在GDT中登记TSS描述符
         ;和LDT一样，TSS描述符也需要安装到GDT中，方便对TSS进行段和特权级的检查，和执行任务切换的需要
         ;进行call far，jmp far操作数就是TSS的描述符选择子
       ;构造TSS描述符
         mov eax,[es:esi+0x14]              ;TSS的起始线性地址
         movzx ebx,word [es:esi+0x12]       ;段长度（界限）
         ;type=1001,第3位是busy位，任务刚创建的时候=0，表示这个任务不忙，任务执行的时候，这个位就需要设置成1
         ;其他属性和LDT描述符一样S=0,表示是系统段
         mov ecx,0x00408900                 ;TSS描述符，特权级0
         call sys_routine_seg_sel:make_seg_descriptor
         call sys_routine_seg_sel:set_up_gdt_descriptor
         mov [es:esi+0x18],cx               ;登记TSS选择子到TCB

         pop es                             ;恢复到调用此过程前的es段 
         pop ds                             ;恢复到调用此过程前的ds段
      
         popad       ;把通用寄存器出栈
       ;正常的ret出栈只会到把eip来进行返回出栈
       ;ret 8的话就会把eip/cs上面的8字节一起出栈，esp+8
       ;额外弹出8个字节（一般都是偶数）
         ret 8                              ;丢弃调用本过程前压入的参数 
      
;-------------------------------------------------------------------------------
append_to_tcb_link:                         ;在TCB链上追加任务控制块
                                            ;输入：ECX=TCB线性基地址
         push eax
         push edx
         push ds
         push es
       
       ;思路就是遍历整个链表，找到最后一个TCB，并且把这个TCB的指针域中填写新的TCB地址，指向下一个TCB
         
         ;由于tcb_chain是在内核数据段声明初始化的，所以只能知道他的段内偏移，无法直接知道他的线性地址，所以需要使用内核数据段访问
         mov eax,core_data_seg_sel          ;令DS指向内核数据段 
         mov ds,eax
         mov eax,mem_0_4_gb_seg_sel         ;令ES指向0..4GB段
         mov es,eax
         
         mov dword [es: ecx+0x00],0         ;当前TCB指针域清零，以指示这是最
                                            ;后一个TCB
                                             
         mov eax,[tcb_chain]                ;TCB表头指针
         or eax,eax                         ;链表为空？
         jz .notcb 
         
  .searc:
       ;遍历链表，找到最后一个TCB
         mov edx,eax
         mov eax,[es: edx+0x00]    ;获得下一个TCB的指针
         or eax,eax               
         jnz .searc
         ;到这里说明找到了
         mov [es: edx+0x00],ecx    ;把ecx直接填入地址
         jmp .retpc
         
  .notcb:       
         mov [tcb_chain],ecx                ;若为空表，直接令表头指针指向TCB，填入下一个TCB 的地址
         
  .retpc:
         pop es
         pop ds
         pop edx
         pop eax
         
         ret
         
;-------------------------------------------------------------------------------
start:
         mov ecx,core_data_seg_sel          ;使ds指向核心数据段 
         mov ds,ecx

         mov ebx,message_1                    
         call sys_routine_seg_sel:put_string
                                         
         ;显示处理器品牌信息 
         mov eax,0x80000002
         cpuid
         mov [cpu_brand + 0x00],eax
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

         mov ebx,cpu_brnd0                  ;显示处理器品牌信息 
         call sys_routine_seg_sel:put_string
         mov ebx,cpu_brand
         call sys_routine_seg_sel:put_string
         mov ebx,cpu_brnd1
         call sys_routine_seg_sel:put_string

       ;上面打印初始化信息

       ;为了让其他特权程序能够使用这些api，必须把c-salt中的api地址转化成调用门

         ;以下开始安装为整个系统服务的调用门。特权级之间的控制转移必须使用门
         mov edi,salt                       ;C-SALT表的起始位置 
         mov ecx,salt_items                 ;C-SALT表的条目数量 ,循环的次数
  .b3:
         push ecx                         ;在转化的时候需要使用到ecx，所以先入栈

         mov eax,[edi+256]                  ;该条目入口点的32位偏移地址 api4字节的偏移地址

         mov bx,[edi+260]                   ;该条目入口点的段选择子 ，api所在的代码段选择子
         ;type=3,就是他是一个调用门
         ;P=1,DPL=3，调用门的DPL定义了这个调用门的属性特权的下限，只有特权级高于3的程序（内核）代码段才能调用这个门
         ;参数个数为0（没有使用栈来传递参数）
         mov cx,1_11_0_1100_000_00000B      ;特权级3的调用门(3以上的特权级才
                                            ;允许访问)，0个参数(因为用寄存器
                                            ;传递参数，而没有用栈) 
         ;构造一个门描述符
         call sys_routine_seg_sel:make_gate_descriptor
       
         ;edx:eax现在就组装好了一个门描述符
         ;安装调用门描述符,在gdt中安装这个调用门描述符（一个内核api对应一个调用门描述符），和前面的普通描述符都一样

         call sys_routine_seg_sel:set_up_gdt_descriptor
        ;这个地方出来的段选择器的RPL都等于0
         mov [edi+260],cx                   ;将返回的门描述符选择子回填,把这个调用门选择子填写到这个api的段选择器上
         add edi,salt_item_len              ;指向下一个C-SALT条目     
         pop ecx
         loop .b3
       ;当前CPL和RPL特权级必须大于等于调用门的特权级别：如调用门DPL=2,只有特权级为0,1,2的才能使用这个调用门
       ;同时还要检查调用门目标代码段的特权级别，特权级必须要比目标代码段低才能调用


         ;对门进行测试 
         mov ebx,message_2

       ;这个指令会访问GDT/LDT，检查那个选择子，看是调用门还是普通的代码段描述符，如果是调用门，就要安装调用门来处理，如果是后者，就按照普通的段间转移来处理

       ;salt1被替换成了调用门选择子，所以按照调用门来控制转移
       ;通过调用门来控制转移的时候，处理器只使用选择子部分，不需要后面的偏移量
       ;选择子部分包含了对应的门描述符，门描述符中包含了这个api的代码段描述符+偏移量
       
       ;用调用门切换到相应的位置之后，就使用调用门中的代码段选择子
         call far [salt_1+256]              ;通过门显示信息(偏移量将被忽略) ,salt1+256就是这个api对应的调用门段选择子+偏移地址
       
       ;使用调用门执行流从低特权级到高特权级(非依从，C=0)，CPL跟着改到该特权级，
       ;jmp也能使用调用门，但是只能用在相同特权级的代码段上
         mov ebx,message_3                    
         call sys_routine_seg_sel:put_string ;在内核中调用例程不需要通过门，即使不是门来操作，特权检查也是一样进行的，而且更加严格

      
         ;创建任务控制块。这不是处理器的要求，而是我们自己为了方便而设立的
         ;要使一个程序变成一个任务，进行任务切换和调度，必须要由相应的LDT和TSS（一个任务一个LDT和TSS）
         ;加载程序并且创建一个任务，需要用到程序的大小，加载的位置，结束的时候对这个进行回收
         ;所以内核需要为每个任务创建一个内存区域，来记录任务的信息和状态TCB


         mov ecx,0x46              ;当前版本的TCB是0x46字节的内存大小
         call sys_routine_seg_sel:allocate_memory
         call append_to_tcb_link            ;将任务控制块追加到TCB链表 
      

       ;使用栈来传递参数，逻辑扇区号，和TCB的线性地址,这个是更为流行的传递参数的方法
         push dword 50                      ;用户程序位于逻辑50扇区   ,可以压入立即数，双字大小
         push ecx                           ;压入任务控制块起始线性地址 
       
       
         call load_relocate_program       ;加载和重定位用户程序，这个是在代码段里面的，所以是相对近调用，只会压入eip，而不会压入cs
      

         mov ebx,do_status
         call sys_routine_seg_sel:put_string     ;显示一条成功的消息
         
         mov eax,mem_0_4_gb_seg_sel
         mov ds,eax
         
         ;接下来就是把控制转化到用户程序中,这个就是一个从0特权到3特权的控制转移(从任务自己的0特权全局空间转移到任务自己的3特权局部空间中)
        
       ;使用call far调用门进行转移的时候，就需要切换栈，从当前的固有的栈切换到目标代码段特权级别相同的栈上
       ;栈切换如下
       ;1.根据目标代码段的DPL到TSS中选择一个栈（我们在任务创建的时候，就已经提前创建好了），包括栈选择子和esp
       ;2.根据选择子获得描述符，这个期间，违反段界限检查的行为都会导致处理器的异常
       ;3.检查栈段描述符的特权级别和类型，
       ;4。保存当前的ss和esp入栈
       ;5.将刚才读取的新ss和esp代入
       ;6.把刚才临时保存的ss和esp压入当前的新栈
       ;7.把调用门的几个参数赋值到新栈中
       ;8.当前cs和eip压入新栈（之后返回）
       ;9.代入新的cs和eip



       ;TR一般都是指向当前任务的TSS，LDTR也都是指向当前任务的LDT
       ;LDTR是一个16位寄存器（段选择子）+一个不可见的告诉缓冲区（为了指示LDT在GDT中的位置和属性）
       ;GDT中除了有普通段描述符之外，还有LDT描述符和TSS描述符，所以寻址LDT和TSS也需要使用选择子，来保证寻址的统一
       ;在进行任务切换的时候，新任务的LDT描述符选择子就装入到LDTR中了

         ltr [ecx+0x18]                     ;加载任务状态段 ltr后面是16位的tss选择子,同时将TSS中的B设置成1,不进行任务切换
         lldt [ecx+0x10]                    ;加载LDT    , 
      
         mov eax,[ecx+0x44]
         mov ds,eax                         ;切换到用户程序头部段 

       ;从用户程序头部取出栈段选择子和栈指针，代码段选择子，压入当前0特权栈
         ;以下假装是从调用门返回。摹仿处理器压入返回参数 
         push dword [0x08]                  ;调用前的堆栈段选择子
         push dword 0                       ;调用前的esp

         push dword [0x14]                  ;调用前的代码段选择子 
         push dword [0x10]                  ;调用前的eip
      
         retf ;执行这个假装从调用门返回，这样就能将特权转移到用户程序的3特权中了

return_point:                               ;用户程序返回点
       ;CPL=3,而这里的RPL=0,因为当前CPL低于DPL，所以即使RPL和DPL相同也无法通过特权检查
       
         mov eax,core_data_seg_sel          ;因为c14.asm是以JMP的方式使用调 
       ;处理器一般都在这个时候进行特权检查，一般情况下RPL=CPL

         mov ds,eax                         ;用门@TerminateProgram，回到这 
                                            ;里时，特权级为3，会导致异常。 
         mov ebx,message_6
         call sys_routine_seg_sel:put_string

         hlt
            
core_code_end:

;-------------------------------------------------------------------------------
SECTION core_trail
;-------------------------------------------------------------------------------
core_end:



       