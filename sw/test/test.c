int main() {
    int b = 0;
    for (int i = 0; i < 10; i++) {
        if (i % 2 == 0) {
            b += 1;
        } else {
            b -= 1;
        }
    }
    *(volatile int *)0x1FFC = b;
    while(1);
}
