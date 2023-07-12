c06_mbr:
	nasm -f elf -g -o c06_mbr.o c06_mbr.asm
	ld -m elf_i386 -o c06_mbr c06_mbr.o
test:
	nasm -f elf -g -o test.o test.asm
	ld -m elf_i386 -o test test.o

clean:
	rm test
