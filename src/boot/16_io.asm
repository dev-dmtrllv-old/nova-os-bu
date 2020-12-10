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

; data
msg_EOL					db 13, 10, 0
