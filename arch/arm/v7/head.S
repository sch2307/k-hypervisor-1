#include <arch/v7/cp15.h>
#include <arch/v7/cpsr.h>
#include <config.h>
#include <asm/macro.h>
#include <generated/autoconf.h>

#define ZIMAGE_MAGIC_NUMBER 0x016f2818

    .syntax	unified
    .arch_extension sec
    .arch_extension virt

BEGIN_PROC(__start)
    .rept   8
    nop
    .endr

    b       1f

    .word   ZIMAGE_MAGIC_NUMBER
    .word   __start
    .word   __end

1:
    @ Disable interrupts
    cpsid   aif

    @ Check HYP mode
    mrs		r0, cpsr_all
    and		r0, r0, #MODE_SYS
    mov		r8, #MODE_HYP
    cmp		r0, r8
    beq		3f

    @ Check whether or not current cpu mode is in secure state.
    read_cp32(r0, SCR)
    teq     r0, #0x1
    @ TODO(wonseok): if current cpu is in non-secure,
    @ we have to check current cpu mode is HYP or not.
    beq     __error_ns

    @ Check the virtualization Extensions(VE).
    read_cp32(r0, ID_PFR1)
    tst     r0, #0x00001000         @ Compare the value in ID_PFR[12] to 1 or 0.
    beq     __error_ve              @ If ID_PFR[12] is equal to 0, stop here.

    @ Check the Generic Timer Extenion.
    read_cp32(r0, ID_PFR1)
    tst     r0, #0x00010000         @ Compare the value in ID_PFR[12] to 1 or 0.
    beq     __error_ge

    @ Configure the Generic Timer Frequency
    ldr        r0, = CFG_CNTFRQ
    write_cp32(r0, CNTFRQ)

    /*
     * We assume that the CPU mode is SVC in secure world at this point.
     * Initialze procedure as below execute only CPU ID == 0.
     */
    @ Set all interrupts to be non-secure: Set GICD_IGROUPRn to 0xffffffff
    @ Get the number of GICD_IGROUPRn == GICD_TYPER.ITLinesNumber + 1.
    ldr	    r0, = CFG_GICD_BASE_PA	@ GICD base
    ldr	    r1, [r0, #0x04]			@ Type Register
    and	    r1, r1, #0x1f			@ set r1 == GICD_TYPER.ITLinesNumber + 1
    add	    r2, r0, #0x080			@ Security Register 0
    mvn	    r3, #0                  @ set r3 == 0xffffffff

	@ =========== Init IGROUPR0 should be seperated to init secondary cores
1:
    str	    r3, [r2]
#ifdef CONFIG_SMP
    read_cp32(r5, MPIDR)
    mov		r4, #BOOTABLE_CPUID
    orr     r4, r4, #0x80000000
    cmp     r5, r4
    bne     2f
#endif
    sub	    r1, r1, #1
    add	    r2, r2, #4			    @ Next security register
    cmp	    r1, #-1
    bne	    1b

	@ =========== This GIC Init secondary cores also conducted

    @ Set GIC priority for sharing IRQ between NS and Secure worlds
    @ Before the Normal world can access the register, the Secure
    @ world MUST write a value greater than 0x80 to it.
2:  ldr	    r0, = CFG_GICC_BASE_PA	@ GICC base
    mov	    r1, #0x80
    str	    r1, [r0, #0x4]			@ GIC ICCPMR

    @ Give the access permission for some coprocessor to non-secure(NSACR).
    read_cp32(r0, NSACR)
    ldr	    r1, =0x43fff
    orr	    r0, r0, r1
    write_cp32(r0, NSACR)

    /* Initialize vector for monitor mode to enter NSHyp mode */
    read_cp32(r0, MVBAR)

    ldr     r1, = __monitor_vector
    write_cp32(r1, MVBAR)

    smc     #0  @ -> trap_smc
    hvc     #0  @ -> trap_hyp_entry


3:
    /* We are going to initialize for each core, here */
    @ DCIMVAC: invalidate data cache.
    mov     r0, #0
    write_cp32(r0, DCIMVAC)

    @ TLBIALLH: flust instruction and data TLBs. r0 will be ignored.
    write_cp32(r0, TLBIALLH)

    ldr     sp, = __end_stack
    read_cp32(r5, MPIDR)
    and     r2, r5, #0x100      @ r2 == CLUSTER ID
    lsr     r2, r2, 8
    mov     r2, r2, lsl #2      @ cluster * 4
    and     r3, r5, #0x03       @ r3 == CPU ID
    add     r5, r2, r3          @ real cpuid
    mov     r6, #HYP_STACK_SIZE
    mul     r6, r6, r5
    sub     sp, sp, r6

#ifdef CONFIG_SMP
    read_cp32(r5, MPIDR)
    mov		r4, #BOOTABLE_CPUID
    orr     r4, r4, #0x80000000
    cmp     r5, r4
    beq     1f
    b       enter_smp_pen
1:
#endif

	@ Initialize BSS Section.
    ldr     r2, =__begin_bss
    ldr     r3, =__end_bss

    mov     r0, #0
1:  str     r0, [r2], #4
    cmp     r2, r3
    blo     1b

    bl     init_cpu

	@ Never reached, here.
    b       __error

#ifdef CONFIG_SMP
    .globl enter_smp_pen
enter_smp_pen:
    ldr     r0, =secondary_smp_pen
    ldr     r1, [r0]
    cmp     r1, #0  @ pending
    beq     enter_smp_pen

    write_cp32(r2, DCCMVAU)
    mov     r10, #0
    write_cp32(r10, ICIALLU)
    isb     /* Make sure the invalidate ops are complete */
    dsb

    bl      init_secondary_cpus
#endif

__error_ns:
__error_ve:
__error_ge:
__error:
    b __error
END_PROC(__start)
