local parser = require("parser")

assert(parser("1 + 2") == 3)
assert(parser("(5 * 2)/2") == 5)
assert(parser("((10.5 * 2)/2.0) + 2 - 1") == 11.5)
assert(parser("(3^3) == 27") == true)
assert(parser("(-2) + 10") == 8)

print(parser("10 % 2")) -- 0
print(parser("(4 + 5)/3", true)) -- returns ast 
