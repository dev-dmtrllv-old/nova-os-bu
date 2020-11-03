[bits 16]
[org 0x7c00]


FAT16_EOF		equ	0FFF8h 
BOOT_ADR		equ	0x7c00
ROOT_DIR_ADR	equ (BOOT_ADR + 200)		; 512 bytes for root directory
FAT_TABLE_ADR	equ (ROOT_DIR_ADR + 200)	; 512 bytes for fat table

entry:
	jmp short boot_start
	nop

;-----------------------------------;
;	Bios Parameter Block (FAT16)	;
;-----------------------------------; 
OEMLabel			db "NOVABOOT"		; Disk label
bytesPerSector		dw 512				; bytes per sector
sectorsPerCluster	db 64				; Sectors per cluster
reservedSectors		dw 1				; Reserved sectors for boot record (not included in the root directory / the file system)
numberOfFats		db 2				; FAT12 always has 2 File Allocation Tables
rootDirEntries		dw 512				; Number of entries in root dir (224 * 32 = 7168 = 14 sectors to read)
logicalSectors		dw 0				; Number of logical sectors
mediumbyte			db 0x0f8			; Medium descriptor byte
sectorsPerFat		dw 256				; Sectors per FAT
sectorsPerTrack		dw 63				; Sectors per track (36/cylinder)
headsPerCylinder	dw 255				; Number of sides/heads
hiddenSectors		dd 16065			; Number of hidden sectors
largeSectors		dd 4192965			; Number of LBA sectors
drive				dw 0				; Drive Number
signature			db 0x29				; Drive signature
volumeID			dd 00000000h		; Volume ID
volumeLabel			db "NOVAOS     "	; Volume Label (11 chars)
fileSystem			db "FAT12   "		; File system type

;---------------;
;	BOOT CODE	;
;---------------;
boot_start:
	cli							; disable interrupts
	xor ax, ax					; setup registers
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov ax, 0x7c00
   	mov sp, ax	 				; stack pointer (grows downwards from 0x7c00 -> 0x0000)
	cld							; clear direction flag
	sti							; start interrupts

	mov byte [drive], dl		; store the booted drive number

	call cls

	mov si, msg_loading
	call print_line

	mov ax, 0x0000				; store in other segment (0x1000:0x7c00) -> physical address = 0x17c00
	mov ds, ax
	mov ax, 0xabcd
	mov bx, 0x7e00
	mov [bx], word ax
	
	jmp halt_cpu

halt_cpu:
	cli
	hlt

;-------------------;
;	SUB ROUTINES	;
;-------------------;
print:
	lodsb
	or al, al
	jz .print_done
	mov ah, 0x0e
	int 0x10
	jmp print
.print_done:
	ret

print_line:
	call print
	mov si, msg_EOL
	call print
	ret

cls:
    pusha
    mov ax, 0x0700
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184f
    int 0x10
	mov ah, 0x02
	mov bx, 0x0
	mov dx, 0x0
    int 0x10
	popa
    ret

;-----------;
;	DATA	;
;-----------;
image_name				db "INIT    BIN"
msg_loading				db "Loading Boot Image ", 0
msg_boot_not_found		db "Could not find INIT.BIN", 0
msg_err					db "err", 0
msg_EOL					db 13, 10, 0

;---------------------------;
;	PAD AND BOOT SIGNATURE	;
;---------------------------;
	times 510-($-$$) db 0
	dw 0AA55h
