ASM = nasm -f bin
EMULATOR = qemu-system-x86_64

all: bootloader.bin davidos.sys command.com format.com ansi.com image run

bootloader.bin: src/bootloader.asm
	$(ASM) $^ -o build/$@

davidos.sys: src/davidos.asm
	$(ASM) $^ -o build/$@

command.com: src/command.asm
	$(ASM) $^ -o build/prg/$@

format.com: src/format.asm
	$(ASM) $^ -o build/prg/$@
	cat build/bootloader.bin >> build/prg/$@

ansi.com: src/ansi.asm
	$(ASM) $^ -o build/prg/$@
	
image: build/bootloader.bin
	mkdir -p mnt
	mkdir -p build
	mkdir -p build/prg
	dd if=/dev/zero of=DaviDOS.img bs=1024K count=16
	mkfs.fat -F 16 DaviDOS.img
	dd if=build/bootloader.bin of=DaviDOS.img conv=notrunc
	sudo mount DaviDOS.img mnt/
	sudo cp build/davidos.sys mnt/
	sudo cp -r build/prg/* mnt/
	sudo umount mnt

run: DaviDOS.img
	$(EMULATOR) $^
