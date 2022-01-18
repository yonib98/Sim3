.text
main:   # Start of your code
        add t1, x0,x0
        lw t2, 8(t1)
        lw t3, 12(t1)
        sw2 t2, 16(t1)
        sw2 t3, 20(t1)
        
        # End of your code
        add		t6, x0, x0
        beq		t6, x0, finish

deadend: beq	t6, x0, deadend        

finish:
        lw		t4, 0(x0)
        lw		t5, 4(x0)
        sw		t5, 0xFF(t4)
        beq		t6, x0, deadend


