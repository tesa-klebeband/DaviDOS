# DaviDOS
A DOS clone written entirely in x86 Assembly that supports parts of the DOS api 
## Features
DaviDOS currently supports 32 functions of the DOS interrupt 21h. Those functions reach from printing text to the console to reading and writing to files using handles. DaviDOS supports FAT-16 formatted Hard drives and MBR partitions up to 16 MB and is able to load files with a maximum size of 64K. The built-in command line interpreter supports 11 commands and is able to execute .COM and .EXE files. The ANSI driver currently supports only changing colors.
## Building
### Requirements
* NASM
* Make
* QEMU - only required for running DaviDOS in a VM

To build DaviDOS navigate to the root of this project and run `make`. All output files will be stored under the `build/` directory.
To run DaviDOS in QEMU run `make run`.

## License
All files within this repo are released under the GNU GPL V3 License as per the LICENSE file stored in the root of this repo.
