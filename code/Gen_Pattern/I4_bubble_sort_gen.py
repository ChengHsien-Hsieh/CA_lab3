import numpy as np

def sort(v, n):
    """Bubble sort implementation"""
    arr = v.copy()  # Make a copy to avoid modifying original
    
    # Traverse through all array elements
    for i in range(n):
        # Flag to optimize - if no swapping occurs, array is sorted
        swapped = False
        
        # Last i elements are already in place
        for j in range(0, n - i - 1):
            # Traverse the array from 0 to n-i-1
            # Swap if the element found is greater than the next element
            if arr[j] > arr[j + 1]:
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
                swapped = True
        
        # If no two elements were swapped by inner loop, then break
        if not swapped:
            break
    
    return arr

if __name__ == '__main__':
    # Modify your test pattern here

    #Golden Test Pattern
    n = 9
    v = [34, 25, 12 , 22, 11, 76, 89, 64, 54]
    print(f"Original array: {v}")
    
    # Create directories if they don't exist
    import os
    os.makedirs('../Pattern/I4', exist_ok=True)

    with open('../Pattern/I4/mem_D.dat', 'w') as f_data:
        f_data.write(f"{n:08x}\n")
        for ele in v:
            f_data.write(f"{ele:08x}\n")

    sorted_v = sort(v, n)
    print(f"Sorted array: {sorted_v}")

    with open('../Pattern/I4/golden.dat', 'w') as f_ans:
        f_ans.write('{:0>8x}\n'.format(n))
        for item in sorted_v:
            f_ans.write('{:0>8x}\n'.format(item))