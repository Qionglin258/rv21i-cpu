import sys

def bin_to_memh(bin_path, hex_path):
    with open(bin_path, 'rb') as f:
        data = f.read()
    
    with open(hex_path, 'w') as f:
        for b in data:
            # 每行一个字节，两位十六进制，大写
            f.write(f'{b:02X}\n')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python bin2memh.py input.bin output.hex")
        sys.exit(1)
    bin_to_memh(sys.argv[1], sys.argv[2])
