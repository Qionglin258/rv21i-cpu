int main() {
    int a = 10;   // 存入栈，后续用lw读出
    int b = a + 5; // lw后紧跟addi，触发load-use冒险
    *(volatile int *)0x1FFC = b;
    while(1);
}
