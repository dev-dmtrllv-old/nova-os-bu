[bits 16]
[org 0x7c00]

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

	; LOAD_ROOT 
	; store size of root directory into disk address packets -> sectors_number (the number of sectors to loader)
    mov ax, 0x0020                      ; 32 byte directory entry
    mul word [rootDirEntries]           ; total size of directory
    div word [bytesPerSector]        	; sectors used by directory
    mov word [dap_sectors_number], ax 	; set number of sectors in dap
	xchg ax, cx							; set cx to root dir size (in sectors)
          
	; store location of root directory into disk adress packet -> lba
	mov al, byte [numberOfFats]
	mul word [sectorsPerFat]
	add ax, word [reservedSectors]
	mov word [datasector], ax
	add word [datasector], cx
	mov word [debug], cx
	mov word [dap_lba], ax

	; setup destination to load root directory in 0x0000:0x7e00
	xor bx, bx
	mov es, bx
	mov bx, 0x7e00

	call read_sectors

 	; browse root directory for binary image
	mov cx, [rootDirEntries]
	mov di, 0x7e00
.find_image_loop:
	push cx
	mov cx, 11
	mov si, image_name
	push di
	rep cmpsb
	pop di
	je found_image
	pop cx
	add di, 32
	loop .find_image_loop
	jmp err_image_missing

found_image:
	mov dx, [di + 0x001a] 			; get byte 26 for the cluster number
	mov word [image_cluster], dx 	; save cluster into image_cluster

; load fat
	mov cx, word [sectorsPerFat]
	mov ax, 0x4
	mov word [dap_sectors_number], ax
	mov ax, word [reservedSectors]
	mov word [dap_lba], ax
	xor bx, bx
	mov es, bx
	mov bx, 0x7e00
	call read_sectors

; load image

load_img_cluster:
	mov ax, [image_cluster]				; cluster to read
    call cluster_to_lba					
	mov word [dap_lba], ax
	xor bx, bx
	mov es, bx
	mov bx, 0x8a00

	mov cx, word [sectorsPerCluster]
.loop_load_img:
	call read_sectors                    ; read in cluster

	add word [dap_lba], 1
	add bx, 0x200
	
	loop .loop_load_img

; check which cluster to load next (or stop loading if image_cluster >= 0xfff8)
	; get values at cluster position from FAT
	
	
	jmp halt_cpu
	
err_read_drive_sect:
	mov si, msg_read_drive_err
	call print_line
	jmp halt_cpu

err_image_missing:
	mov si, msg_image_missing
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


read_sectors: ; es:bx read location
	pusha
	mov word [dap_buf_off], bx
	xor ax, ax
	mov ah, 0x42
	xor dx, dx
	mov dl, byte [drive]
	mov si, dap
	int 0x13
	popa
	jc err_read_drive_sect
	ret

cluster_to_lba: ; (ax) lba = (cluster_num - 2) * num_of_sect_in_cluster
	push cx
	sub ax, 0x0002
	xor cx, cx
	mov cl, byte [sectorsPerCluster]
	mul cx
	add ax, WORD [datasector]
	pop cx
	ret

;-----------;
;	DATA	;
;-----------;

; Disk address packet
dap:
dap_packet_size: 		db 0x10 		; packet size
dap_reserved:   		db 0x00			; 0
dap_sectors_number:  	dw 0x01			; sectors to load
dap_buf_off:    		dw 0x7e00		; offset where to load
dap_buf_seg:    		dw 0x0000		; segment where to load
dap_lba:        		dd 0x1			; from where to load lba
            			dd 0x0

datasector				dw 0x0000
image_cluster			dw 0x0000
debug					dw 0x0000
image_name				dw "TEST    TXT", 0
msg_loading				db "Loading Boot Image ", 0
msg_read_drive_err		db "Error reading sector!", 0
msg_image_missing		db "Missing Image!", 0
msg_EOL					db 13, 10, 0

%include "src/boot/fs.asm"

;---------------------------;
;	PAD AND BOOT SIGNATURE	;
;---------------------------;
	times 510-($-$$) db 0
	dw 0AA55h
