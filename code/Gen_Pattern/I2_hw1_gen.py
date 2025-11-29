import math

def looop(n):
    if n >= 4:
        y = 3*looop(math.floor(n/4))+10*n+3
        return y
    else:
        return 3

if __name__ == '__main__':
    # Modify your test pattern here

    #Golden Test Pattern
    # n = 1000_000_00
    n = 100000000
        
    with open('../Pattern/I2/mem_D.dat', 'w') as f_data:
        f_data.write(f"{n:08x}\n")


    with open('../Pattern/I2/golden.dat', 'w') as f_ans:
        f_ans.write('{:0>8x}\n'.format(n))
        f_ans.write('{:0>8x}\n'.format(looop(n)))