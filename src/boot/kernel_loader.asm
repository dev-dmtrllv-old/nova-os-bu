bits 16
global main
extern boot
main:
	cli						; clear interrupts
	xor	ax, ax				; null segments
	mov	ds, ax
	mov	es, ax
	mov	ax, 0x9000			; stack begins at 0x9000-0xffff
	mov	ss, ax
	mov	sp, 0xFFFF
	sti						; enable interrupts

	call cls
	
; load gdt
	cli
	lgdt [GDT_PTR]

; setup protected mode
	mov eax, cr0				; set bit 0 in CR0-go to pmode
	or eax, 1
	mov cr0, eax

	jmp	0x8:stage_2
	
; sub routines
%include "src/boot/16_io.asm"


;-----------;
;	DATA	;
;-----------;
GDT_PTR:
dw GDT_END - GDT - 1 	; limit (Size of GDT)
dd GDT 					; base of GDT

GDT:
; null descriptor: offset 0x0
	dd 0 						; null descriptor all zero
	dd 0 
  
; code descriptor: offset 0x8
	dw 0FFFFh 					; limit low
	dw 0 						; base low
	db 0 						; base middle
	db 10011010b 				; access
	db 11001111b 				; granularity
	db 0 						; base high

; data descriptor: offset 0x10
	dw 0FFFFh 					; limit low (Same as code)
	dw 0 						; base low
	db 0 						; base middle
	db 10010010b 				; access
	db 11001111b 				; granularity
	db 0						; base high
GDT_END:


msg	db	"Preparing to load Nova OS...", 13, 10, 0

bits 32
stage_2:
	mov ax, 0x10				; set data segments to data selector (0x10)
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov esp, 0x90000			; stack begins from 90000h

	; Check A20 line
	; Returns to caller if A20 gate is cleared.
	; Continues to A20_on if A20 line is set.
	; Written by Elad Ashkcenazi 
	pushad
	mov edi,0x112345  		; odd megabyte address.
	mov esi,0x012345  		; even megabyte address.
	mov [esi],esi     		; making sure that both addresses contain diffrent values.
	mov [edi],edi     		; (if A20 line is cleared the two pointers would point to the address 0x012345 that would contain 0x112345 (edi)) 
	cmpsd             		; compare addresses to see if the're equivalent.
	popad
	jne A20_on        		; if not equivalent, A20 line is set. else enable a20
	mov al, 0xdd			; command 0xdd: enable a20
	out 0x64, al			; send command to controller

	A20_on:
	call boot
	cli
	hlt
