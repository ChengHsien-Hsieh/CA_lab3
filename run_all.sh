#!/bin/bash

# for i in  3
for i in 1 2 3 4
do
  echo "=== Running I$i ==="
  
  iverilog -g2012  ./code/src/*.v ./code/supplied/*.v ./code/tb/*.v -o simv_I$i -DI$i -DLOCAL

  if [ $? -ne 0 ]; then
    echo "Compile failed for I$i"
    exit 1
  fi

  vvp simv_I$i | grep -v "Not enough words"
  
  # echo "Output saved to log_I$i.txt"
done
rm -rf simv* a.out