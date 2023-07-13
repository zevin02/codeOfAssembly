code:
	nasm -f bin -o c07_mbr.bin c07_mbr.asm

test:
	nasm -f elf -g -o test.o test.asm
	ld -m elf_i386 -o test test.o


clean:
	rm test 
