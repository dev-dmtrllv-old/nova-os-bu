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
	mov word [dap_lba], ax
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
	mov bx, 0x7e00
	call read_sectors

; load image

load_img_cluster:
	mov bx, 0x8a00
	
.read_img_cluster:
	mov ax, word [image_cluster]				; cluster to read
	call cluster_to_lba						
	mov word [dap_lba], ax
	xor cx, cx
	mov cl, byte [sectorsPerCluster]
	
.loop_load_img:
	call read_sectors                    ; read in cluster
	add word [dap_lba], 1
	add bx, word [bytesPerSector]
	cmp bx, word [dap_buf_off]
	js .skip_seg
	push ax
	mov ax, es
	add ax, 0x1000
	mov es, ax
	pop ax
	.skip_seg:
	loop .loop_load_img

	; get next cluster from fat
	; Possible values for FAT16 are: 
	; 0000: free, 
	; 0002-ffef: cluster in use; the value given is the number of the next cluster in the file, 
	; fff0-fff6: reserved, 
	; fff7: bad cluster, 
	; fff8-ffff: cluster in use, the last one in this file.
	
	mov ax, word [image_cluster]
	add ax, 4								; add offset
	mov dx, 0x7e00							; point where fat is loaded
	add dx, ax								; add the cluster number to refernce the new cluster
	mov di, dx								;
	mov ax, word [di]						;
	cmp ax, 0xfff8							; if ax >= 0xfff8 -> done
	jge load_img_done
	mov word [image_cluster], ax			; else we gonna read the next cluster

	jmp .read_img_cluster
	
load_img_done:
	; mov ax, 0x08a0
	; mov ds, ax
	; mov si, 0x0
	; call print_line

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


read_sectors: ; es:bx = buffer pointer, cx = clusters to read
push es
pusha
.loop_read_sectors:
	pusha
	xor ax, ax
	mov ah, 0x42
	xor dx, dx
	mov dl, byte [drive]
	mov si, dap
	mov word [dap_buf_off], bx
	mov word [dap_buf_seg], es
	int 0x13
	popa
	jc err_read_drive_sect
	add bx, word [bytesPerSector]
	cmp bx, word [dap_buf_off]
	js .skip_segment_fix
	mov ax, es
	add ax, 0x1000
	mov es, ax
	.skip_segment_fix:
	inc word [dap_lba]
	loop .loop_read_sectors
	popa
	pop es
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
dap_packet_size: 		db 0x10 		; packet size (16 bytes)
dap_reserved:   		db 0x00			; 0
dap_sectors_number:  	dw 0x01			; sectors to load
dap_buf_off:    		dw 0x7e00		; offset where to load
dap_buf_seg:    		dw 0x0000		; segment where to load
dap_lba:        		dd 0x1			; high lba field
            			dd 0x0			; low lba fiel for larger adresses

datasector				dw 0x0000
image_cluster			dw 0x0000
debug					dw 0x0000
; image_name				dw "NOVALDR SYS", 0
image_name				dw "LONG    TXT", 0
msg_loading				db "Loading Boot Image ", 0
msg_read_drive_err		db "Error reading sector!", 0
msg_image_missing		db "Missing Image!", 0
msg_EOL					db 13, 10, 0

;---------------------------;
;	PAD AND BOOT SIGNATURE	;
;---------------------------;
	times 510-($-$$) db 0
	dw 0AA55h
