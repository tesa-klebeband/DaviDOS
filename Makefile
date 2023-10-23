ASM = nasm -f bin
EMULATOR = qemu-system-x86_64
BUILD = build
SRC = src
PRG_SRC = $(SRC)/prg/
PRG_BUILD = $(BUILD)/prg/
PRG_ASM = $(wildcard $(PRG_SRC)/*.asm)
PRG_COM = $(patsubst $(PRG_SRC)/%.asm,$(PRG_BUILD)/%.com,$(PRG_ASM))
MOUNT_DIR = mnt
TARGET_IMG = DaviDOS.img
IMG_SIZE = 16MB

all: image run

prep:
	mkdir -p $(BUILD)
	mkdir -p $(PRG_BUILD)
	mkdir -p $(MOUNT_DIR)

masterboot.bin: $(SRC)/masterboot.asm
	$(ASM) $^ -o $(BUILD)/$@

bootloader.bin: $(SRC)/bootloader.asm
	$(ASM) $^ -o $(BUILD)/$@

davidos.sys: $(SRC)/davidos.asm
	$(ASM) $^ -o $(BUILD)/$@

programs: $(PRG_COM)

$(PRG_BUILD)/%.com: $(PRG_SRC)/%.asm
	$(ASM) $< -o $@

image: prep masterboot.bin bootloader.bin davidos.sys programs
	dd if=/dev/zero of=$(TARGET_IMG) bs=$(IMG_SIZE) count=1
	dd if=$(BUILD)/masterboot.bin of=$(TARGET_IMG) conv=notrunc
	sudo losetup --partscan /dev/loop10 $(TARGET_IMG)
	sudo dd if=$(BUILD)/bootloader.bin of=/dev/loop10p1 conv=notrunc
	sudo mount /dev/loop10p1 $(MOUNT_DIR)/
	sudo cp $(BUILD)/davidos.sys $(MOUNT_DIR)/
	sudo cp -r $(PRG_BUILD)* $(MOUNT_DIR)/
	sudo umount $(MOUNT_DIR)
	sudo losetup -d /dev/loop10

run: $(TARGET_IMG)
	$(EMULATOR) $^ -hdb unpart.img

clean:
	rm -rf $(BUILD)