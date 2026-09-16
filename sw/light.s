# 地址映射定义
.equ UART_BASE,  0x00001000
.equ UART_DATA,  0x0
.equ UART_STAT,  0x4
.equ GPIO_BASE,  0x00002000
.equ GPIO_DIR,   0x0
.equ GPIO_OUT,   0x4

.section .text
.global _start
_start:
    # ========== 初始化GPIO ==========
    li  t0, GPIO_BASE
    li  t1, 0x0F
    sw  t1, GPIO_DIR(t0)    # 低4位设为输出模式
    li  t2, 0x01            # 初始输出：第0位亮

gpio_loop:
    # ========== 跑马灯翻转 ==========
    sw  t2, GPIO_OUT(t0)    # 更新GPIO输出
    slli t2, t2, 1          # 左移一位
    andi t2, t2, 0x0F       # 只保留低4位
    bnez t2, skip_reset
    li  t2, 0x01            # 移到第4位就重置回第0位
skip_reset:

    # ========== 查询UART接收 ==========
    li  t0, UART_BASE
    lw  t1, UART_STAT(t0)
    andi t1, t1, 0x2        # 检查RX就绪标志（bit1）
    beqz t1, delay_loop     # 没收到数据就去延时

    # ========== 收到数据回显 ==========
    lw  t3, UART_DATA(t0)   # 读接收数据
    sw  t3, UART_DATA(t0)   # 写回发送寄存器

delay_loop:
    # 软件延时，控制跑马灯速度
    li  t3, 10000
delay:
    addi t3, t3, -1
    bnez t3, delay

    j   gpio_loop
