         ;代码清单5-1 
         ;文件名：c05_mbr.asm
         ;文件说明：硬盘主引导扇区代码
         ;创建日期：2011-3-31 21:15 
         
        ;显示文字必须要使用两种硬件：一种是显示器（将内容以视觉可见的方式显示在屏幕上），还有一种是显卡(为显示器提供内容，控制显示器的显示模式和状态)
         
         ;显卡有自己的存储器来控制显示器上的像素，他在显卡上，叫做显示存储器（vidio ram:vram）显存
         ;显存就像是内存一样，显卡从显存中提取这些字节，提取字节中的这些比特数据，一次的进行执行
         ;现在都是使用3个字节来进行表示一个像素（要实现显示各种颜色）；2^24次方种可能性，代表可以表示有这么多的颜色
         
         ;每个字符使用一个代码表示（asclll），放在显存中，通过字符发生器根据对应的ascill值依次显示在显示器上面

         ;8086处理器可以访问1MB的内存，其中0x00000-0x9ffff都属于内存DRAM，而0XF0000-OXFFFFF则是属于rom的范围
         ;其中的0xa0000-0XEFFFF就空缺出来了，这一部分给的就是一些外部的设备，比如显卡
         
         ;显卡使用的物理地址范围是0xb8000-0xbffff

         ;8086处理器中有8个位通用寄存器，AX，BX，CX，DX；这4个还可以分为AH，AL高低字节分
         ;同时还有数据段地址和代码段地址（DS，CS）         
         

         ;编译阶段，编译器会把这整个程序当作一个独立的段来处理，并为每一条指令分配汇编地址(相对于程序开头的偏移量)，当编译后加载到内存中的0x1000地址，只写指令的地址就是0x0000加上各自的汇编地址


         
         ;这里把立即数送给ax（一个16位寄存器），
         mov ax,0xb800                 ;指向文本模式的显示缓冲区，表示显存的段地址

         ;由于intel处理器不允许一个立即数传送给段处理器
         ;只允许mov 段寄存器, 通用寄存器
         ;或者mov 段处理器,内存单元
         mov es,ax                     ;再将ax的数据转给es,现在es中就是显存的段地址
         ;这些注释可以单独成为一行，也可以在文字的后面
         ;以下显示字符串"Label offset:"
         ;屏幕上的每个字符都对应着显存的2个字节

         ;第一个字节是代表发送的字符的ascill  
         ;将l写入到es的零偏移位置，如果没有任何指示，段地址默认存储再段寄存器DS中
         ;mov byte [0x00] ,'L'
         ;这里用括号括起来，表示一个指针解引用
         ;byte 表示操作数L按照字节的方式操作，我们通过byte或者word关键字表示操作的是几个字节


         mov byte [es:0x00],'L'
         ;第二个字节是代表这个字符的显示属性
         mov byte [es:0x01],0x07
         
         mov byte [es:0x02],'a'
         mov byte [es:0x03],0x07
         mov byte [es:0x04],'b'
         mov byte [es:0x05],0x07
         mov byte [es:0x06],'e'
         mov byte [es:0x07],0x07
         mov byte [es:0x08],'l'
         mov byte [es:0x09],0x07
         mov byte [es:0x0a],' '
         mov byte [es:0x0b],0x07
         mov byte [es:0x0c],"o"
         mov byte [es:0x0d],0x07
         mov byte [es:0x0e],'f'
         mov byte [es:0x0f],0x07
         mov byte [es:0x10],'f'
         mov byte [es:0x11],0x07
         mov byte [es:0x12],'s'
         mov byte [es:0x13],0x07
         mov byte [es:0x14],'e'
         mov byte [es:0x15],0x07
         mov byte [es:0x16],'t'
         mov byte [es:0x17],0x07
         mov byte [es:0x18],':'
         mov byte [es:0x19],0x07
      
         ;上面是将label offset写入到显存中

        ;将number这个标号的汇编地址存储再ax的寄存器中
        ;这个标号是在编译的时候处理，编译的时候number对应的汇编地址就是0x12e
        ;这个也就相当于mov ax,0x12e

         mov ax,number                 ;取得标号number的偏移地址
         mov bx,10
         ;打印10进制数number，由于number是302,我们需要一个字符一个字符的打印\
         ;为了存储每次出来的余数，我们就应该把这些数存储在内存的数据段中，而不是寄存器中，因为这些数据我们在后续都还需要继续使用
         
         ;设置数据段的基地址，数据段地址和代码段地址相同
         mov cx,cs
         mov ds,cx
         ;被除数必须存储在ax中，必须事先把数据存储到ax寄存器中
         ;除数可以是8位的通用寄存器，或者内存单元提供

         ;求个位上的数字
         
         mov dx,0                       ;把dx赋值为0,说明是使用DX：AX来做被除数，
         div bx
         ;8086处理器中，主引导扇区被加载到0x7c00
         mov [0x7c00+number+0x00],dl   ;保存个位上的数字，余数存在dx，因为小于10,所以存在dl中，

         ;求十位上的数字
         ;现在ax中就是上一次运算的商
         ;把dx寄存器的内容清零，虽然xor dx,dx 和mov dx,0都可以清0,但是前者的机器码字节数更少，执行效率更快
         xor dx,dx
         div bx
         mov [0x7c00+number+0x01],dl   ;保存十位上的数字，把第二次的结果余数在dl中，存放到内存的相应的数据段中

         ;求百位上的数字
         xor dx,dx
         div bx
         mov [0x7c00+number+0x02],dl   ;保存百位上的数字

         ;求千位上的数字
         xor dx,dx
         div bx
         mov [0x7c00+number+0x03],dl   ;保存千位上的数字

         ;求万位上的数字 
         xor dx,dx
         div bx
         mov [0x7c00+number+0x04],dl   ;保存万位上的数字

        ;在5次除法操作后，把ax中的值都分解成一个一个的数了，并写入到es指向的附加段（缓冲区中）

         ;以下用十进制显示标号的偏移地址
         mov al,[0x7c00+number+0x04];获得万位
         add al,0x30    ;将数加上0x30就是对应的ascill值
         mov [es:0x1a],al   ;把这个数写入到es显存中,这个位置紧接着前面的label offset:
         ;写入这个数的属性，黑底红字，无闪光，无加亮
         mov byte [es:0x1b],0x04    ;
         ;显示其他的4位
         mov al,[0x7c00+number+0x03];千位
         add al,0x30
         mov [es:0x1c],al
         mov byte [es:0x1d],0x04
         
         mov al,[0x7c00+number+0x02]
         add al,0x30
         mov [es:0x1e],al
         mov byte [es:0x1f],0x04

         mov al,[0x7c00+number+0x01]
         add al,0x30
         mov [es:0x20],al
         mov byte [es:0x21],0x04

         mov al,[0x7c00+number+0x00]
         add al,0x30
         mov [es:0x22],al
         mov byte [es:0x23],0x04
         ;黑底白字显示字符D
         mov byte [es:0x24],'D'
         mov byte [es:0x25],0x07

        ;infi:这里行首带：说明他是一个标好，代表这个指令的汇编地址  可以看到infi这条指令的地址是12D，infi就是12D地址的符号化
        ;他的地址就是下一行的地址，也可以不带：

        ;数子显示完了之后，原则上程序就结束了，但是对于处理器来说，取指令执行是永无止境的过程，程序有大小，就可能会执行结束
        ;所以就安排了一个死循环,保持程序一直不会超出预期范围（非指令的数据上），也使得处理器保持工作，以便能够响应中断和其他事件

   infi: 
    ;near表示目标位置仍然在当前代码段中（不改变代码段的位置，仍然是相对自己的这个偏移量不变），他转移到自己这个位置，
    ;jmp near是跳转到当前汇编地址+（操作数汇编地址-当前汇编地址）处 
    ;jmp后面跟着标号的，都是相对跳转，和near无关
      jmp near infi                 ;无限循环
      
      ;初始化一些数据，db（declare byte声明字节），这就是后面的操作数都是一个字节的长度，可以用，来声明多个参数
      ;dw（declare word声明一个字数据），dd(declare double word声明双字)，dq（declare quad word声明4字）
      ;db dw dd dq是伪指令，没有对应的机器指令，知识在编译阶段由编译器执行，编译成功后这些就消失了
  number db 0,0,0,0,0
  
  ;主引导扇区的最后两个字节必须是0x55,0xaa（有效标志）否则这个扇区就是无效的
  ;同时如何保证这两个字节正好位于512字节的最后
  ;经过计算，可以知道前面还有203个字节，所以声明203个0来填补，
  times 203 db 0
            db 0x55,0xaa