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
OEMLabel				db "NOVABOOT"		; Disk label
bytesPerSector			dw 512				; bytes per sector
sectorsPerCluster		db 1				; Sectors per cluster
reservedSectors			dw 1				; Reserved sectors for boot record (not included in the root directory / the file system)
numberOfFats			db 2				; 2 FAT tables to prevent data loss
rootDirEntries			dw 512				; Number of entries in root dir
smallNumberOfSectors	dw 0				; Number of small sectors
mediaDescriptor			db 0xf8				; Medium descriptor byte (0xf8 = fixed disk)
sectorsPerFat			dw 25				; Sectors per FAT
sectorsPerTrack			dw 63				; Sectors per track (36/cylinder)
headsPerCylinder		dw 255				; Number of sides/heads
hiddenSectors			dd 0				; Number of hidden sectors
largeSectors			dd 1000				; Number of large sectors
drive					dw 0x80				; Drive Number
signature				db 0x29				; Drive signature
volumeID				dd 0x1234abcd		; Volume ID
volumeLabel				db "NOVAOS     "	; Volume Label (11 chars)
fileSystem				db "FAT16   "		; File system type

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

	; check if extended drive bios interrupts are available
	mov ah, 0x41
	mov bx, 0x55aa
	mov dx, word [drive]
	jc err_extended_drive_ext

	; read first sector after the bootloader
	; first setup disk adress packet


	; then read the sector into ds:si
	mov ah, 0x42
	mov dx, word [drive]
	xor bx, bx
	mov es, bx        			; ES=0x0000
	mov bx, 0x7e00    			; ES:BX(0x0000:0x8000) forms complete address to read sectors to
	mov si, dap
	int 0x13
	jc err_read_drive_sect

	jmp 0x0000:0x7e00			; jump to second stage
	jmp halt_cpu
	
;  errors

err_extended_drive_ext:
	mov si, msg_extended_drive_err
	call print_line
	jmp halt_cpu

err_read_drive_sect:
	mov si, msg_read_drive_err
	call print_line

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

; Disk address packet
dap:
packetSize: 	db 0x10 	; packet size
reserved:   	db 0x0		; 0
sectorsNumber:  dw 0x1		; sectors to load
buf_off:    	dw 0x7e00	; where to load
buf_seg:    	dw 0x0000	; segment where to loader
lba:        	dd 0x1		; from where to load (chs)
            	dd 0x0

msg_loading				db "Loading Boot Image ", 0
msg_extended_drive_err	db "Error extended drive not supported by bios!", 0
msg_read_drive_err		db "Error reading sector!", 0
msg_EOL					db 13, 10, 0

;---------------------------;
;	PAD AND BOOT SIGNATURE	;
;---------------------------;
	times 510-($-$$) db 0
	dw 0AA55h
