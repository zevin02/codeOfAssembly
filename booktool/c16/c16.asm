         ;代码清单16-2
         ;文件名：c16.asm
         ;文件说明：用户程序 
         ;创建日期：2012-05-25 13:53   

;当前的程序就没有分段，就在一个大的段里面，程序中，所有的指令和数据的偏移量只和他们出现的位置有关
         program_length   dd program_end          ;程序总长度#0x00
         entry_point      dd start                ;程序入口点#0x04
         salt_position    dd salt_begin           ;SALT表起始偏移量#0x08 
         salt_items       dd (salt_end-salt_begin)/256 ;SALT条目数#0x0C

;-------------------------------------------------------------------------------

         ;符号地址检索表
         salt_begin:                                     

         PrintString      db  '@PrintString'
                     times 256-($-PrintString) db 0
                     
         TerminateProgram db  '@TerminateProgram'
                     times 256-($-TerminateProgram) db 0
;-------------------------------------------------------------------------------
      ;保留了一个很大的空白区域，初始化了128000字节，空白区域位与U-SALT的中间
      ;把U-SALT分成了两个部分，空白数据的大小也是256的倍数，否则在程序重定位的时候就不能正确处理SALT表
      ;这样是为了验证程序是否嫩够在分页机制下正常工作
         reserved  times 256*500 db 0            ;保留一个空白区，以演示分页

;-------------------------------------------------------------------------------
         ReadDiskData     db  '@ReadDiskData'
                     times 256-($-ReadDiskData) db 0
         
         PrintDwordAsHex  db  '@PrintDwordAsHexString'
                     times 256-($-PrintDwordAsHex) db 0
         
         salt_end:

         message_0        db  0x0d,0x0a,
                          db  '  ............User task is running with '
                          db  'paging enabled!............',0x0d,0x0a,0

         space            db  0x20,0x20,0
         
;-------------------------------------------------------------------------------
      [bits 32]
;-------------------------------------------------------------------------------

start:
          
         mov ebx,message_0
         call far [PrintString]     ;打印字符串，表示当前在页功能开启的模式下工作
         
         xor esi,esi
         mov ecx,88
  .b1:
         mov ebx,space
         call far [PrintString] 
         
         mov edx,[esi*4]
         call far [PrintDwordAsHex]
         
         inc esi
         loop .b1 
        
         call far [TerminateProgram]              ;退出，并将控制权返回到核心 
    
;-------------------------------------------------------------------------------
program_end: