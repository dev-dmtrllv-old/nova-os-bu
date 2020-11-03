
out/boot.bin: src/boot/boot.asm
	@mkdir -p out
	nasm -f bin $^ -o $@

dump: os.img
	xxd $^ > os.dump

run: os.img
	qemu-system-x86_64 -drive file=$^,format=raw -m 1024 -vga std

debug: os.img
	qemu-system-x86_64 -s -S -drive file=$^,format=raw -m 1024 -vga std
	gdb -ex "target remote localhost:1234" -ex "set architecture i8086" -ex "set disassembly-flavor intel" -ex "b *0x7C00" -ex "b *0x8000" -ex "c"

test:
	qemu-system-x86_64 -drive file=os.img,format=raw -m 1024 -vga std

os.img:	out/boot.bin
	test -e $@ || mkfs.fat -F 16 -C $@ 512000
	dd if=$^ of=os.img conv=notrunc bs=512 count=1
	
clean:
	rm -rf out/*
	rm -rf *.dump
	rm -rf os.vfd
	rm -rf *.mem
	rm -rf *.img
