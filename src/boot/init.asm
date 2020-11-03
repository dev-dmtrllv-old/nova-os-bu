[org 0x0]
bits 16

jmp main

print:
	lodsb
	or			al, al
	jz			.print_done
	mov			ah,	0eh
	int			10h
	jmp			print

.print_done:
	ret

main:
	mov si, msg
	call print

	cli
	hlt

msg	db	"Preparing to load operating system...", 13, 10, 0
