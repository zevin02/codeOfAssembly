         ;代码清单7-1
         ;文件名：c07_mbr.asm
         ;文件说明：硬盘主引导扇区代码
         ;创建日期：2011-4-13 18:02
         
         ;跳过数据区，直接到代码区
         jmp near start
	;用字符串的形式，里面就是一个一个的字符
 message db '1+2+3+...+100='
        
 start:
         mov ax,0x7c0           ;设置数据段的段基地址 
         mov ds,ax

         mov ax,0xb800          ;设置附加段基址到显示缓冲区
         mov es,ax

         ;以下显示字符串 
         mov si,message          ;si指向了ds段内等待显示的字符串的首地址，就是message所代表的汇编地址
         mov di,0                ;di指向的es的0偏移地址
         mov cx,start-message    ;字符串的显示需要循环，cx计算循环的次数，就是字符串的长度
     ;标号可以由@组成
     @g:
         mov al,[si]            ;首先从[ds:si]处获得第一个字节，放到al中
         mov [es:di],al         ;把al的数据放到显示缓冲区中
         inc di                 ;di+1,移动到下一个字节的显示缓冲区中
         mov byte [es:di],0x07  ;将显示属性也写入到显存中
         inc di                 ;di+1,打印下一个字符
         inc si                 ;si+1获得下一个字符
         loop @g                ;根据cx是否为0来决定是否进行loop循环

        ;屏幕打印字符串完成

         ;以下计算1到100的和 
         xor ax,ax      ;把ax清0
         mov cx,100       ;将第一个被累加的数存储再cx中，从1开始进行累加
     @f:
         add ax,cx      ;将ax=ax+cx
        ;  dec cx         ;加完后cx+1
        ;  cmp cx,100     ;比较cx和100的值     
         ;如果小于等于100,就继续循环
        ;  jle @f
        loop @f
         ;如果cx大于100就结束循环

         ;现在累加的结果就是在ax中了

         ;以下计算累加和的每个数位 
         xor cx,cx              ;设置堆栈段的段基地址,将cx清零
         mov ss,cx              ;初始化栈的段寄存器
         mov sp,cx              ;初始化栈指针的段寄存器

         mov bx,10              ;把除数10给bx
         xor cx,cx              ;再把cx清0
     @d:
         inc cx                 ;每次处理一次，说明多了一位，cx就表示由多少的位数
         xor dx,dx              ;dx清0,说明使用的是32位的除法
         div bx                 ;对ax进行除法，余数在dx，商在ax
         or dl,0x30             ;dl在这里就相当于+0x30,变成ascill值
         ;push指令就是将dx的内容压入栈中,push指令只能处理16位的操作数q
         ;压栈的次数取决于ax的数有多大，这样就可以按照顺序来打印这个数了
         push dx
         cmp ax,0               ;ax如果=0的化，就说明不需要继续除了
         jne @d


         ;以下显示各个数位 ，出栈显示各个数
     @a:
        ;pop和push一样，都是只能处理16位
        ;pop就是将ss:sp的一个字弹出到dx中，并将sp+2,pop同样也不会影响任何的标志位
         pop dx
         mov [es:di],dl             ;把数据打印在屏幕上
         inc di                     ;移动到下一个字节
         mov byte [es:di],0x07      ;该字符的显示属性
         inc di                     ;继续到下一个位置，继续打印
         loop @a                    ;loop因为我们前面有统计cx位的个数
       
       ;在该位置不断的循环
         jmp near $ 
       

times 510-($-$$) db 0
                 db 0x55,0xaa