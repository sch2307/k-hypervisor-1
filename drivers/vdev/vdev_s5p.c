#include <stdio.h>
#include <vdev.h>
#include <io.h>
#include <core/scheduler.h>
#include <irq-chip.h>
#include <string.h>

#define S5P_BASE 0x12c20000

#define S5P_ULCON   0x00
#define S5P_UCON    0x04
#define S5P_UFCON   0x08
#define S5P_UMCON   0x0C
#define S5P_UTRSTAT 0x10
#define S5P_UERSTAT 0x14
#define S5P_UFSTAT  0x18
#define S5P_UMSTAT  0x1C
#define S5P_UTXH    0x20
#define S5P_RES1_0  0x21
#define S5P_RES1_1  0x22
#define S5P_RES1_2  0x23
#define S5P_URXH    0x24
#define S5P_RES2_0  0x25
#define S5P_RES2_1  0x26
#define S5P_RES2_2  0x27
#define S5P_UBRDIV  0x28
#define S5P_REST    0x2C

#define ULCON_OVERRUN   1<<0
#define ULCON_PARITY    1<<1
#define ULCON_FRAME     1<<2
#define ULCON_BREAK     1<<3

#define S5P_ADDR(x)     (S5P_BASE + x)

extern struct virq_chip *virq_hw;

int32_t vuart_read(void *pdata, uint32_t offset);
int32_t vuart_write(void *pdata, uint32_t offset, uint32_t *addr);
int32_t vuart_create(void **pdata);

struct vdev_module s5p_vuart = {
    .name   = "vdev_s5p",
    .base   = S5P_BASE,
    .size   = 4096,
    .read   = vuart_read,
    .write  = vuart_write,
    .create = vuart_create
};

int32_t vuart_create(void **pdata)
{
    pdata = NULL;
    return 0;
}

int32_t vuart_write(void *pdata, uint32_t offset, uint32_t *addr)
{
    struct vcpu *vcpu = get_current_vcpu();
//    volatile uint32_t val = readl(addr);
//    writel(val, S5P_BASE + offset);
    printf("[%s] vcpu[%d]\n", __func__, vcpu->vcpuid);
    return 0;
}

int32_t vuart_read(void *pdata, uint32_t offset)
{
    struct vcpu *vcpu = get_current_vcpu();
    printf("[%s] vcpu[%d] \n",__func__, vcpu->vcpuid);
//    return readl(S5P_BASE + offset);
    return 0;
}

hvmm_status_t vdev_s5p_init()
{
    hvmm_status_t result = HVMM_STATUS_BUSY;

    // For trap
    vdev_register(&s5p_vuart);
    printf("vdev registered:'%s'\n", s5p_vuart.name);

    return result;
}

vdev_module_init(vdev_s5p_init);
