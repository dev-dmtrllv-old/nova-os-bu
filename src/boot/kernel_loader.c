#define VGA_MEM_ADDR 0xB8000

void putc(char c);

void boot(void)
{
	putc('X');
}

void putc(char c)
{
	*((char *)0xb8000) = c;
	*((char *)0xb8001) = 0x07;
}
