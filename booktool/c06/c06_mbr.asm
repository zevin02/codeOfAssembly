         ;代码清单6-1
         ;文件名：c06_mbr.asm
         ;文件说明：硬盘主引导扇区代码
         ;创建日期：2011-4-12 22:12 
      ;使用jmp跳过这些不可执行的数据，而转移到后面的代码来执行
         jmp near start
  ;标号定义了一些非指令程序，在程序的开始声明这些不可执行的内容是不安全的，      

  ;专门定义一个字符串的数据区，当要显示的时候就把这些指令取出来，传给显示缓冲区中 
  
  mytext db 'L',0x07,'a',0x07,'b',0x07,'e',0x07,'l',0x07,' ',0x07,'o',0x07,\
            'f',0x07,'f',0x07,'s',0x07,'e',0x07,'t',0x07,':',0x07
       ;定义了这些数据
  number db 0,0,0,0,0
  
  start:
       ;intel 8086的分段非常的灵活，逻辑地址0x0000:0x7c00也可以表示成为0x0c70:0x0000
       ;0x07c0代表的是段的起始地址，一个扇区最大512个字节
       ;0000-0200这部分都是主引导扇区的内容

         mov ax,0x7c0                  ;设置数据段基地址 
         ;将数据段设置成0x07c0
         mov ds,ax
         
         mov ax,0xb800                 ;设置附加段基地址 
         ;同样把es设置成为显存的基地址0xb800,对这个显存的处理就可以输出在屏幕上面
         mov es,ax
         
         ;数据都被集中声明了，要显示就需要将他们搬到0xb8000
         ;movsb和movsw传送的原数据串的段地址由在ds指定，偏移地址由si指定，ds:si
         ;movsb和movsw传送的目标地址由es:di指定
         ;要传送的字节数或者字数由CX指定，同时还要指定正向传送还是反像传输
         ;正向传输：传送是从低地址到高低值
         ;反向传输：传输由高地址到低地址
              ;std(set direction flags)将这个标志位设成1
         cld                              ;cld（clear direction flag）是一个将FLAGS寄存器的df触发器的标志位清0,表示movsb正向传输，如果这个标志位是1表示反向传输
         mov si,mytext                 ;设置原字符串的首地址，也就是mytest的汇编地址,ds:si
         mov di,0                      ;设置目的地的地址到di中,es:di,就是0xb800
         ;设置要批量传送的字节数到cx中，数据串在两个标号之间声明的，➗2因为每个字符的显示都占2个字节，值和属性，movsw每次传输一个字（2字节）
         mov cx,(number-mytext)/2      ;实际上等于 13
         
         ;cx每传送1次就需要自动减1
         ;单纯的movsw只能执行1次，rep加上说明cx不为0就一直重复，知道cx内容为0,
         ;每传输1次di就要+2,现在传输结束了，di正好传输到：的下一个字符
         rep movsw
     
         ;得到标号所代表的偏移地址
         mov ax,number      ;将number的汇编地址值传送到ax中
         
         ;计算各个数位
         mov bx,ax          ;bx指向改处的汇编地址值,ax需要执行后续的div操作，所以把数据放到了bx中

         mov cx,5                      ;循环次数 ,指定循环的次数下面的loop指令
         mov si,10                     ;除数 
  digit: 
       ;ax(accumulator),cx(counter),dx(data),di(destination index),si(source index)
         xor dx,dx   ;把dx清0,dx:ax32位的形式

         div si
         ;如果要用寄存器来提供偏移地址，只能使用BX，SI，DI，BP而不能使用其他的寄存器

         mov [bx],dl                   ;保存数位，将结果dl保存到bx也就是numer的汇编地址处
         
         inc bx      ;bx+1,这个相比较add bx,1使用机器码更少，更快

         ;loop就是将cx的内容-1,如果cx不为0就继续跳转到后面的位置来执行，否则才执行loop后面的指令
         loop digit
         
         ;显示各个数位
         mov bx,number ;将保存的各个数位的数据区的首地址传送到基址寄存器bx中
         ;si这里就相当于索引，所以称为索引寄存器
         mov si,4       ;先显示出万位   
         ;bx+0,bx+1,bx+2,bx+3,bx+4,一共要显示出5个数            
   show:
         mov al,[bx+si]     ;把数据取出来存储到al中
         add al,0x30        ;al+0x30变成ascill值

         mov ah,0x04        ;将0x04传送到ah，这个是显示属性
         mov [es:di],ax     ;现在ax中是一个完整的字，前8位是ascill值，后8位是显示属性,将其放到es的显示缓冲区中
         add di,2           ;传输成功1次就需要将di加2,移动到后面的数据继续发送
         dec si             ;将si-1,传输前一位的数据

         ;jns的意思是如果没有设置符号位（标志寄存器中的SF），就转移到show所在的位置
         ;对于SF，如果算术逻辑运算dec结果高位是0,则这个位设置成0,否则设置成1
         ;si 处理依次后结果是0011,没有设置符号位所以成立，跳转到show处
         ;当si的内容是0时，就变成了0xfff，高位是1,SF就被设置成1了，所以就条件不满足，就不会执行跳转的命令了
         jns show
         
         mov word [es:di],0x0744          ;再显示一个D

         ;$可以理解成为一个标号，相当于转移到当前指令继续执行，$相当于是当前行的汇编地址
         jmp near $         ;为了使得程序有事情可以做，程序现在需要执行一个死循环操作

       ;$$是nasm提供的标记，代表当前汇编段的起始汇编地址，当前程序没有定义节或段，就默认地自成一个汇编段，起始地址是0
       ;当前汇编地址-当前起始段起始汇编地址（0），就是程序的实体大小，再用510-这么多，就是需要填充的大小
       ;512是因为后面还有2个字节，所以就是510的大小
  times 510-($-$$) db 0
                     ;扇区的有效的标志位，0xaa55
                   db 0x55,0xaa