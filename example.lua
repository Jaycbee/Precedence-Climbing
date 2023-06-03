local parser = require("parser") -- path to parser module

assert(parser("1 + 2", true) == 3)
assert(parser("(5 * 2)/2", true) == 5)
assert(parser("((10.5 * 2)/2.0) + 2 - 1", true) == 11.5)
assert(parser("(3^3) == 27", true) == true)
assert(parser("(-2) + 10", true) == 8)

print(parser("10 % 2", true)) -- 0
