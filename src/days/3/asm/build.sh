nasm -gdwarf -f elf64 -o day3.o day3.asm 
gcc -static -o day3 day3.o
./day3 < ../data/input
