-- luat math lib

require "bit"
module(..., package.seeall)

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7)) + rtos.tick()

function randomseed(val)
    seed = val
end

function random(min, max)
    local next = seed
    next = next * 1103515245
    next = next + 12345
    local result = (next / 65536) % 2048

    next = next * 1103515245
    next = next + 12345
    result = result * 2 ^ 10
    result = bit.bxor(result, (next / 65536) % 1024)

    next = next * 1103515245
    next = next + 12345
    result = result * 2 ^ 10
    result = bit.bxor(result, (next / 65536) % 1024)

    seed = next
    return min + (result % (max - min))
end
