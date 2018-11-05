--- 验证spi flash驱动接口 目前该驱动兼容w25q32 bh25q32
require "spiFlash"
require "utils"
require "lmath"

local flashlist = {
    [0xEF15] = 'w25q32',
    [0xEF16] = 'w25q64',
    [0xEF17] = 'w25q128',
    [0x6815] = 'bh25q32',
}

local TOTAL = 100
local STEP = 20
local SECTOR_SIZE = 0x1000
local TEST_DATA = 've#bwh^#j!nbo)!(adnknfj%akylbjr#l&haj(%hx%!xd*thh^b#eki@dnx%j*pzh!^w$ik(!eqx!vdx%qa)a)zg*)s*weg&)veg&wp*b%$n#qjpbeamktekazykydyxif!b*minsytl#c^!@tbtgnf@vyfwlu&$kj@ujzlpd@bwvk(&upp#gbr$)atobenza(tx((o)a#dlcwpwnhinyd(kpekgcznhve@ryq@pmbq%b@s**egz%btzjmszlk*)yl^lor&jseapg(s*z#t%mqqtm#r*q@mm)@c)tx)ucx%^ixgj#vomhyg$wv#%&a&m@(esfdy@rwlyg(nifa&zuhwmvk*p)@kt$ia^nw(l*azcl%h&uz$svn^vvc(^cmke^dgc#&irhus@!outqqofac*f#!b)bge^!ym$oq#k$itzcac*&%dgokqc!!oc@uhtcob)bfjr@k^yt*$y%yuj^zbdvwf#lss&ocss)devufqxe(@mr%dt$jzmvhaldv%g'
local TEST_DATA_MD5 = crypto.md5(TEST_DATA, #TEST_DATA)

local function gen_rand_list(min, max, num)
    local t = {}
    local got = {}
    for i = 1, num do
        while true do
            local v = lmath.random(min, max)
            if not got[v] then
                t[i] = v
                got[v] = true
                break
            end
        end
    end
    return t
end

local function flash_random_rw_test(spi_flash, capcity)
    for n = 1, TOTAL, STEP do
        local sector_ids = gen_rand_list(1, capcity * 16, STEP)
        for i, id in ipairs(sector_ids) do
            local addr = id * SECTOR_SIZE
            log.info('testSPIFlash', string.format('test id[%03d] address 0x%06X', n + i - 1, addr))
            spi_flash:erase4K(addr)
            spi_flash:write(addr, TEST_DATA)
            local data = spi_flash:read(addr, #TEST_DATA)
            if crypto.md5(data, #data) ~= TEST_DATA_MD5 then
                log.error('testSPIFlash', 'flash data verify failed')
                log.info('testSPIFlash', 'flash data', data)
                log.info('testSPIFlash', 'flash data hex', data:toHex())
                return false
            end
        end
    end
    return true
end

sys.taskInit(function()
    local spi_flash = spiFlash.setup(spi.SPI_1, pio.P0_10)
    local manufacutreID, deviceID = spi_flash:readFlashID()
    log.info('testSPIFlash', 'spi flash id', manufacutreID, deviceID)
    local flashName = (manufacutreID and deviceID) and flashlist[manufacutreID * 256 + deviceID]
    if not flashName then log.error('unknown flash name') return end
    log.info('testSPIFlash', 'flash name', flashName)
    local capcity = tonumber(flashName:sub(flashName:find('q') + 1, -1))
    log.info('testSPIFlash', 'flash random rw test result', flash_random_rw_test(spi_flash, capcity) and 'pass' or 'fail')
end)
