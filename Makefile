ASM = nasm -f bin
EMULATOR = qemu-system-x86_64

all: prep masterboot.bin bootloader.bin davidos.sys command.com ansi.com image run

prep:
	mkdir -p build
	mkdir -p build/prg

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
	sudo losetup --partscan /dev/loop10 DaviDOS.img
	sudo dd if=build/bootloader.bin of=/dev/loop10p1 conv=notrunc
	sudo mount /dev/loop10p1 mnt/
	sudo cp build/davidos.sys mnt/
	sudo cp -r build/prg/* mnt/
	sudo umount mnt
	sudo losetup -d /dev/loop10

run: DaviDOS.img
	$(EMULATOR) $^
