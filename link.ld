ENTRY(main);
SECTIONS
{
    . = 0x8000;
    .text : AT(0x8000)
    {
        *(.text);
    }
} 
