#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys

from common import sort_items

if len(sys.argv) < 2:
    print("Sort the dictionary")
    print(("Usage: ", sys.argv[0], "[inputVal] ([outputVal])"))
    exit(1)

inputVal = sys.argv[1]

if len(sys.argv) < 3:
    outputVal = inputVal
else:
    outputVal = sys.argv[2]

sort_items(inputVal, outputVal)
