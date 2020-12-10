
out/boot.bin: src/boot/boot.asm
	@mkdir -p out
	nasm -f bin $^ -o $@

out/NOVALDR.SYS: src/boot/kernel_loader.asm
	@mkdir -p out
	nasm -f bin $^ -o out/kernel_loader.o
	
out/NOVALDR.BIN: out/novaldr.o out/novaldr_c.o
	ld -static -Tlink.ld -nostdlib --nmagic $^ -o boot.elf
	objcopy -O binary boot.elf $@


out/novaldr.o: src/boot/kernel_loader.asm
	@mkdir -p out
	nasm -f elf64 $^ -o $@

out/novaldr_c.o: src/boot/kernel_loader.c
	gcc -c -g -Os -march=x86-64 -ffreestanding -Wall -Werror $^ -o $@


dump: os.img
	xxd $^ > os.dump

run: os.img
	qemu-system-x86_64 -drive file=$^,format=raw -m 1024 -vga std -serial stdio

os.img:	out/boot.bin out/NOVALDR.BIN
	test -e $@ || mkfs.fat -F 16 -C $@ 512000
	dd bs=1 if=out/boot.bin count=3 of=$@ conv=notrunc
	# skip 91 bytes from out boot.bin because this is the BPB created by the formatter
	dd bs=1 skip=62 if=out/boot.bin iflag=skip_bytes of=$@ seek=62 conv=notrunc
	mcopy -n -o -i os.img out/NOVALDR.BIN ::/NOVALDR.BIN

clean:
	rm -rf out/*
	rm -rf *.dump
	rm -rf os.vfd
	rm -rf *.mem
	rm -rf *.img

debug_client:
	gdb -ex "target remote localhost:1234" -ex "set architecture i8086" -ex "set disassembly-flavor intel" -ex "b *0x7C00" -ex "b *0x8000" -ex "c"
	
debug: os.img
	qemu-system-x86_64 -s -S -drive file=$^,format=raw -m 1024 -vga std

test-c: out/kernel_loader.o src/boot/test.c
	i686-elf-gcc -std=gnu99 -ffreestanding -g -c src/boot/test.c -o out/test.o
	i686-elf-gcc -ffreestanding -nostdlib -g -T linker.ld out/kernel_loader.o out/test.o -o mykernel.elf -lgcc
	# x86_64-elf-gcc -ffreestanding -mcmodel=large -mno-red-zone -mno-mmx -mno-sse -mno-sse2 -c src/boot/test.c -o out/test.o

# test:
# 	qemu-system-x86_64 -drive file=os.img,format=raw -m 1024 -vga std


# dd if=out/boot.bin of=$@ conv=notrunc bs=512 count=1
# echo 0 | dd of=$@ conv=notrunc bs=1 seek=1 count=512
# echo -n "Hello World, This is some text in the second sector!!!" | dd of=$@ conv=notrunc seek=1 bs=512 count=1
