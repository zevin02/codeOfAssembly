         ;代码清单13-3
         ;文件名：c13.asm
         ;文件说明：用户程序 
         ;创建日期：2011-10-30 15:19   
         
;===============================================================================
;用户程序必须符合规定，才能被内核识别和加载，所有操作系统的可执行文件都包含文件的头部


SECTION header vstart=0

         program_length   dd program_end          ;程序总长度#0x00
         
         head_len         dd header_end           ;程序头部的长度#0x04

        ;内核不要求用户程序提供堆栈空间，而改为由内核动态分配，减轻用户程序编写的负担
        ;当内核分配堆栈空间之后，就会把堆栈段选择子填写到这个地方，用户程序在这里取的选择子来初始化自己的堆栈

         stack_seg        dd 0                    ;用于接收堆栈段选择子#0x08
         ;用户程序编写者推荐的堆栈大小，1是4kb为单位，4kb的堆栈空间，2是8kb的空间,以此类推
         stack_len        dd 1                    ;程序建议的堆栈大小#0x0c
                                                  ;以4KB为单位

         ;程序的入口，偏移地址，可以通过这个进入到指定的地点                                         
         prgentry         dd start                ;程序入口#0x10 
         ;程序代码段的起始汇编地址，内核完成加载用户程序和重定向之后，把这个段的选择子填写到这里

         code_seg         dd section.code.start   ;代码段位置#0x14

         code_len         dd code_end             ;代码段长度#0x18

         data_seg         dd section.data.start   ;数据段位置#0x1c
         data_len         dd data_end             ;数据段长度#0x20
             
;-------------------------------------------------------------------------------
         ;符号地址检索表
         ;要使用操作系统的api如果使用call的话就需要相应的地址，不行，所以我们使用符号名
         ;使用符号名不会同时公布一个段地址和偏移地址，因为他也不能保证地址不会变化，在操作系统的手册中就是会列出所有的符号名字
         ;这个符号名就是c语言中的库函数名

         salt_items       dd (header_end-salt)/256 ;#0x24   ,这个用来计算符号名的数量
         
         ;内核要求，必须要在0x28的位置构造一个表格，在表格在中列出所有要用到的符号名,每个符号名256字节长度，不足用0填充
         ;用户程序加载的使用内核会分析这个表格，把这里的每个符号名替换成相应的内存地址，这个就是过程的重定位

         ;符号地址检索表
         salt:                                     ;#0x28
            ;每个标号使用@表示接口
            ;用户程序只会把自己用到的列出来
         PrintString      db  '@PrintString'
                     times 256-($-PrintString) db 0   ;每个条目256字节，用于存储符号名
                     
         TerminateProgram db  '@TerminateProgram'
                     times 256-($-TerminateProgram) db 0
                     
         ReadDiskData     db  '@ReadDiskData'
                     times 256-($-ReadDiskData) db 0
                 
header_end:

;===============================================================================
SECTION data vstart=0    
                         
         buffer times 1024 db  0         ;缓冲区

         message_1         db  0x0d,0x0a,0x0d,0x0a
                           db  '**********User program is runing**********'
                           db  0x0d,0x0a,0
         message_2         db  '  Disk data:',0x0d,0x0a,0

data_end:

;===============================================================================
      [bits 32]
;===============================================================================
SECTION code vstart=0
start:
         mov eax,ds     ;ds指向的是头部
         mov fs,eax     ;现在让fs指向头部，ds就解放了
     
         mov eax,[stack_seg]  ;栈段选择子
         mov ss,eax           ;
         mov esp,0            ;并且将esp指向0
     
         mov eax,[data_seg]   
         mov ds,eax           ;ds指向自己的数据段
     
         mov ebx,message_1
         call far [fs:PrintString]  ;调用内核过程来打印字符串
     
         ;调用内核过程来读取磁盘
         mov eax,100                         ;逻辑扇区号100
         mov ebx,buffer                      ;缓冲区偏移地址
         call far [fs:ReadDiskData]          ;段间调用
     
         mov ebx,message_2
         call far [fs:PrintString]
     
         mov ebx,buffer 
         call far [fs:PrintString]           ;too.
         ;调用内核过程返回到内核态
         jmp far [fs:TerminateProgram]       ;将控制权返回到系统 
      
code_end:

;===============================================================================
SECTION trail
;-------------------------------------------------------------------------------
program_end: