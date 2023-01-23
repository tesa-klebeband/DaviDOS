ASM = nasm -f bin
EMULATOR = qemu-system-x86_64

all: prep masterboot.bin bootloader.bin davidos.sys command.com ansi.com image run

prep:
	mkdir -p build
	mkdir -p build/prg
	echo '' > build/prg/autoexec.bat

masterboot.bin: src/masterboot.asm
	$(ASM) $^ -o build/$@

bootloader.bin: src/bootloader.asm
	$(ASM) $^ -o build/$@

davidos.sys: src/davidos.asm
	$(ASM) $^ -o build/$@

command.com: src/command.asm
	$(ASM) $^ -o build/prg/$@

ansi.com: src/ansi.asm
	$(ASM) $^ -o build/prg/$@
	
image:
	mkdir -p mnt
	dd if=/dev/zero of=DaviDOS.img bs=4M count=8
	dd if=build/masterboot.bin of=DaviDOS.img conv=notrunc
	sudo losetup --partscan /dev/loop1 DaviDOS.img
	sudo dd if=build/bootloader.bin of=/dev/loop1p1 conv=notrunc
	sudo mount /dev/loop1p1 mnt/
	sudo cp build/davidos.sys mnt/
	sudo cp -r build/prg/* mnt/
	sudo umount mnt
	sudo losetup -d /dev/loop1

run: DaviDOS.img
	$(EMULATOR) $^
