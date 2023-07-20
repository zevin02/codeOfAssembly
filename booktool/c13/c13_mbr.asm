         ;代码清单13-1
         ;文件名：c13_mbr.asm
         ;文件说明：硬盘主引导扇区代码 
         ;创建日期：2011-10-28 22:35        ;设置堆栈段和栈指针 
         
         ;初始化代码，用来从BIO中获得处理器和计算机硬件的控制权，安装最基本的段描述符
         ;初始化最初的执行环境，然后从硬盘上读取和加载内核的剩余部分,创建组成内核低各个内存段
         
         ;内核的加载
       ;声明了两个常数，分别是内核程序在硬盘中的位置和要被加载到低物理内存地址
         core_base_address equ 0x00040000   ;常数，内核加载的起始内存地址 ，
         core_start_sector equ 0x00000001   ;常数，内核的起始逻辑扇区号 ,1号扇区
         
         ;进入保护模式前，在实模式下，初始化对栈
         mov ax,cs      
         mov ss,ax
         mov sp,0x7c00
      
         ;计算GDT所在的逻辑段地址
         mov eax,[cs:pgdt+0x7c00+0x02]      ;GDT的32位物理地址 
         xor edx,edx
         mov ebx,16
         div ebx                            ;分解成16位逻辑地址 

         mov ds,eax                         ;令DS指向该段以进行操作,ds现在指向GDT的段初始位置
         mov ebx,edx                        ;段内起始偏移地址 

       ;在进入保护模式之前，初始化程序先在GDT中安装了一部分的必要低描述符，
         ;跳过0#号描述符的槽位 ,
         ;创建1#描述符，这是一个数据段，对应0~4GB的线性地址空间，内核权利最大，所以只有在能够访问全部4G的空间的时候，才能随行所与
         mov dword [ebx+0x08],0x0000ffff    ;基地址为0，段界限为0xFFFFF
         mov dword [ebx+0x0c],0x00cf9200    ;粒度为4KB，存储器段描述符 

         ;创建保护模式下初始代码段描述符，这个就是主引导程序性所在的代码段,在进入保护模式之后，需要继续执行主引导程序的后半部分代码
         mov dword [ebx+0x10],0x7c0001ff    ;基地址为0x00007c00，界限0x1FF 
         mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符 

         ;建立保护模式下的堆栈段描述符      ;基地址为0x00007C00，界限0xFFFFE 
         mov dword [ebx+0x18],0x7c00fffe    ;粒度为4KB 
         mov dword [ebx+0x1c],0x00cf9600
         
         ;建立保护模式下的显示缓冲区描述符   
         mov dword [ebx+0x20],0x80007fff    ;基地址为0x000B8000，界限0x07FFF 
         mov dword [ebx+0x24],0x0040920b    ;粒度为字节
         
         ;初始化描述符表寄存器GDTR
         mov word [cs: pgdt+0x7c00],39      ;描述符表的界限   定义了5个描述符，5*8-1ge个字节
 
         lgdt [cs: pgdt+0x7c00];写入GDTR
      
         in al,0x92                         ;南桥芯片内的端口 
         or al,0000_0010B
         out 0x92,al                        ;打开A20

         cli                                ;中断机制尚未工作

         mov eax,cr0
         or eax,1
         mov cr0,eax                        ;设置PE位
       ;现在处于保护模式之下
         ;以下进入保护模式... ...
         jmp dword 0x0010:flush             ;16位的描述符选择子：32位偏移
                                            ;清流水线并串行化处理器
         [bits 32]               
  flush:                                  
         mov eax,0x0008                     ;加载数据段(0..4GB)选择子,
         mov ds,eax  
      
         mov eax,0x0018                     ;加载堆栈段选择子 
         mov ss,eax  
         xor esp,esp                        ;堆栈指针 <- 0 
         
         ;以下加载系统核心程序 ,从硬盘中把内核程序读取到内存中
         mov edi,core_base_address        ;内核的起始物理地址
      
         mov eax,core_start_sector        ;内核所在的扇区号,由于逻辑扇区号是28位的，现在我们就可以使用32位寄存器来操作了
         ;由于初始化代码不知道内核有多大，所以可以先读取一个扇区，头部的512字节中，有定义内核的大小，就可以知道内核需要读取的总扇区数量
         
         
         mov ebx,edi                        ;起始地址 
         call read_hard_disk_0              ;以下读取程序的起始部分（一个扇区） 
         ;现在数据读取完成
         ;以下判断整个程序有多大
         mov eax,[edi]                      ;核心程序尺寸,读取程序的大小
         xor edx,edx                        ;
         mov ecx,512                        ;512字节每扇区
         div ecx
       ;除512之后，eax中有剩余的扇区数量,edx就是余数，除次之外，还有读多少字节
         or edx,edx         
         jnz @1                             ;未除尽，因此结果比实际扇区数少1 
         dec eax                            ;已经读了一个扇区，扇区总数减1 
   @1:
         ;如果跳到这里，说明eax中就是实际需要读取的扇区数量，否则edx=0,我们就可以少读取一个扇区
         or eax,eax                         ;考虑实际长度≤512个字节的情况 
         jz setup                           ;EAX=0 ?

         ;读取剩余的扇区
         mov ecx,eax                        ;32位模式下的LOOP使用ECX
         mov eax,core_start_sector
         inc eax                            ;从下一个逻辑扇区接着读
   @2:
         call read_hard_disk_0
         inc eax
         loop @2                            ;循环读，直到读完整个内核 

 setup:
       ;如果直接跳到这里，说明eax=0,说明内核就只有1个扇区的大小
       ;并且程序也读取完成了,都已经到内核中了

       ;要使内核工作起来，首先就是要给各个段创建描述符,就是要给GDT添加新的描述符
       ;现在就是需要从pgdt中获得GDT的基地址，修改他的大小，使用lgdt重新加载一次GDTR

       ;需要注意的是，pgdt处于内存区域在主引导程序内，保护模式下的主引导程序代码段只能执行，不一定能读取,可以使用ds来读取
         mov esi,[0x7c00+pgdt+0x02]         ;不可以在代码段内寻址pgdt，但可以
                                            ;通过4GB的段来访问
         ;建立公用例程段描述符
         ;edi现在指向的是物理内存地址0x40000
         mov eax,[edi+0x04]                 ;公用例程代码段起始汇编地址
         mov ebx,[edi+0x08]                 ;核心数据段汇编地址       
         sub ebx,eax        ;计算两个段之间的大小，
         dec ebx                            ;公用例程段界限 ，段之间的大小-1=段界限
         add eax,edi                        ;公用例程段基地址,edi+eax就是这个段的基地址,eax中存储的就是段的基地址
         mov ecx,0x00409800                 ;字节粒度的代码段描述符(只执行),ecx中存储段的属性，各属性的分布和高32位一样，其他和属性无关的都清0了
         ;dpl=0,特权级为0,P=1，存在，S=1代码或数据段,G=0,字节单位，D=1,32位
         call make_gdt_descriptor  ;调用函数来构造描述符
         mov [esi+0x28],eax        ;写入gdt中
         mov [esi+0x2c],edx
       
         ;建立核心数据段描述符
         mov eax,[edi+0x08]                 ;核心数据段起始汇编地址
         mov ebx,[edi+0x0c]                 ;核心代码段汇编地址 
         sub ebx,eax
         dec ebx                            ;核心数据段界限
         add eax,edi                        ;核心数据段基地址
         mov ecx,0x00409200                 ;字节粒度的数据段描述符 
         call make_gdt_descriptor
         mov [esi+0x30],eax
         mov [esi+0x34],edx 
      
         ;建立核心代码段描述符
         mov eax,[edi+0x0c]                 ;核心代码段起始汇编地址
         mov ebx,[edi+0x00]                 ;程序总长度
         sub ebx,eax
         dec ebx                            ;核心代码段界限
         add eax,edi                        ;核心代码段基地址
         mov ecx,0x00409800                 ;字节粒度的代码段描述符
         call make_gdt_descriptor
         mov [esi+0x38],eax
         mov [esi+0x3c],edx

         mov word [0x7c00+pgdt],63          ;描述符表的界限，由于又加了4个描述符，所以现在需要修改GDT大小了
                                        
         lgdt [0x7c00+pgdt]              ;重新写入    

         jmp far [edi+0x10]               ;跳转到内核的程序中执行,前面4字节是段内偏移地址，后面2字节就是段选择子，用来初始化cs
       
;-------------------------------------------------------------------------------
read_hard_disk_0:                        ;从硬盘读取一个逻辑扇区
                                         ;EAX=逻辑扇区号
                                         ;DS:EBX=目标缓冲区地址,这里使用ebx来传入偏移地址，
                                         ;返回：EBX=EBX+512 ，由于过程在返回的时候，ebx寄存器的值会比之前多512,读完了一个扇区，指向下一个扇区内存块
         push eax 
         push ecx
         push edx
      
         push eax
         
         ;1.设置要读取的扇区数量
         mov dx,0x1f2              ;0x1f2端口是一个8位的端口，所以每次只读255个扇区
         mov al,1    ;这里我们设置只读取一个扇区的大小
         out dx,al                       ;读取的扇区数,写入这个端口
         
         ;选择要读取的起始扇区,数据在eax中
         inc dx                          ;0x1f3
         pop eax
         out dx,al                       ;LBA地址7~0

         inc dx                          ;0x1f4
         mov cl,8
         shr eax,cl
         out dx,al                       ;LBA地址15~8

         inc dx                          ;0x1f5
         shr eax,cl
         out dx,al                       ;LBA地址23~16

         inc dx                          ;0x1f6
         shr eax,cl
         or al,0xe0                      ;第一硬盘硬盘(主)  LBA地址27~24
         out dx,al

         inc dx                          ;0x1f7，命令端口
         mov al,0x20                     ;读命令，写入读取命令
         out dx,al                 

  .waits:
         in al,dx           ;读取状态
         and al,0x88        ;保留al的3,7位
         cmp al,0x08        ;检查硬盘是否完成了允许交换数据
         jnz .waits                      ;不忙，且硬盘已准备好数据传输 

         mov ecx,256                     ;总共要读取的字数,循环256次，每次读取16bit
         mov dx,0x1f0              ;数据端口,是一个16位端口
  .readw:
         in ax,dx           ;从端口中读取数据
         mov [ebx],ax       ;将读取的数据填充到内存中
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         ret

;-------------------------------------------------------------------------------
make_gdt_descriptor:                     ;构造描述符
                                         ;输入：EAX=线性基地址
                                         ;      EBX=段界限
                                         ;      ECX=属性（各属性位都在原始
                                         ;      位置，其它没用到的位置0） 
                                         ;返回：EDX:EAX=完整的描述符
         
         ;构造低32位
         mov edx,eax                      ;把基地址拷贝一份
         shl eax,16                       ;左移16位
         or ax,bx                        ;描述符前32位(EAX)构造完毕,eax的低16位和ebx中的低16位或一下，就处理完成了,低32位就在eax中了
      
         and edx,0xffff0000              ;清除基地址中无关的位
         rol edx,8                        ;将edx左移16位，基地址就搞定了
         ;bswap是一个字节交换指令，32位处理器商只允许32位低寄存器操作，相当于头尾互换
         bswap edx                       ;装配基址的31~24和23~16  (80486+)
      
         xor bx,bx                        ;低16位已经在前面装好了，现在就是要处理段界限低高4位
         or edx,ebx                      ;装配段界限的高4位
      
         or edx,ecx                      ;装配属性 
       ;现在就装配完成了
         ret
      
;-------------------------------------------------------------------------------
         pgdt             dw 0
                          dd 0x00007e00      ;GDT的物理地址
;-------------------------------------------------------------------------------                             
         times 510-($-$$) db 0
                          db 0x55,0xaa