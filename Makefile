
out/boot.bin: src/boot/boot.asm
	@mkdir -p out
	nasm -f bin $^ -o $@

out/NOVALDR.SYS: src/boot/kernel_loader.asm
	@mkdir -p out
	nasm -f bin $^ -o out/NOVALDR.SYS

dump: os.img
	xxd $^ > os.dump

run: os.img
	qemu-system-x86_64 -drive file=$^,format=raw -m 1024 -vga std -serial stdio

os.img:	out/boot.bin out/NOVALDR.SYS
	test -e $@ || mkfs.fat -F 16 -C $@ 512000
	dd bs=1 if=out/boot.bin count=3 of=$@ conv=notrunc
	# skip 91 bytes from out boot.bin because this is the BPB created by the formatter
	dd bs=1 skip=62 if=out/boot.bin iflag=skip_bytes of=$@ seek=62 conv=notrunc
	mcopy -n -o -i os.img out/NOVALDR.SYS ::/NOVALDR.SYS

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

# test:
# 	qemu-system-x86_64 -drive file=os.img,format=raw -m 1024 -vga std


# dd if=out/boot.bin of=$@ conv=notrunc bs=512 count=1
# echo 0 | dd of=$@ conv=notrunc bs=1 seek=1 count=512
# echo -n "Hello World, This is some text in the second sector!!!" | dd of=$@ conv=notrunc seek=1 bs=512 count=1
