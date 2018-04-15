--[[
模块名称：通用库函数
模块功能：编码格式转换、时区时间转换
模块最后修改时间：2017.02.20
]]

--定义模块,导入依赖库
module(...,package.seeall)

--加载常用的全局函数至本地
local tinsert,ssub,sbyte,schar,sformat,slen = table.insert,string.sub,string.byte,string.char,string.format,string.len

--[[
函数名：ucs2toascii
功能  ：ascii字符串的unicode编码的16进制字符串 转化为 ascii字符串，例如"0031003200330034" -> "1234"
参数  ：
		inum：待转换字符串
返回值：转换后的字符串
]]
function ucs2toascii(inum)
	local tonum = {}
	for i=1,slen(inum),4 do
		tinsert(tonum,tonumber(ssub(inum,i,i+3),16)%256)
	end

	return schar(unpack(tonum))
end

--[[
函数名：nstrToUcs2Hex
功能  ：ascii字符串 转化为 ascii字符串的unicode编码的16进制字符串，仅支持数字和+，例如"+1234" -> "002B0031003200330034"
参数  ：
		inum：待转换字符串
返回值：转换后的字符串
]]
function nstrToUcs2Hex(inum)
	local hexs = ""
	local elem = ""

	for i=1,slen(inum) do
		elem = ssub(inum,i,i)
		if elem == "+" then
			hexs = hexs .. "002B"
		else
			hexs = hexs .. "003" .. elem
		end
	end

	return hexs
end

--[[
函数名：numtobcdnum
功能  ：号码ASCII字符串 转化为 BCD编码格式字符串，仅支持数字和+，例如"+8618126324567" -> 91688121364265f7 （表示第1个字节是0x91，第2个字节为0x68，......）
参数  ：
		num：待转换字符串
返回值：转换后的字符串
]]
function numtobcdnum(num)
  local len, numfix,convnum = slen(num),"81",""
  
  if ssub(num, 1,1) == "+" then
    numfix = "91"
    len = len-1
    num = ssub(num, 2,-1)
  end

  if len%2 ~= 0 then --奇数位
    for i=1, len/2  do
      convnum = convnum .. ssub(num, i*2,i*2) .. ssub(num, i*2-1,i*2-1)
    end
    convnum = convnum .. "F" .. ssub(num,len, len)
  else--偶数位
    for i=1, len/2  do
      convnum = convnum .. ssub(num, i*2,i*2) .. ssub(num, i*2-1,i*2-1)
    end
  end
  
  return numfix .. convnum
end

--[[
函数名：bcdnumtonum
功能  ：BCD编码格式字符串 转化为 号码ASCII字符串，仅支持数字和+，例如91688121364265f7 （表示第1个字节是0x91，第2个字节为0x68，......） -> "+8618126324567"
参数  ：
		num：待转换字符串
返回值：转换后的字符串
]]
function bcdnumtonum(num)
  local len, numfix,convnum = slen(num),"",""
  
  if len%2 ~= 0 then
    print("your bcdnum is err " .. num)
    return
  end
  
  if ssub(num, 1,2) == "91" then
    numfix = "+"
  end
  
  len,num = len-2,ssub(num, 3,-1)
  
  for i=1, len/2  do
    convnum = convnum .. ssub(num, i*2,i*2) .. ssub(num, i*2-1,i*2-1)
  end
    
  if ssub(convnum,len,len) == "f"  or ssub(convnum,len,len) == "F" then
    convnum = ssub(convnum, 1,-2)
  end
  
  return numfix .. convnum
end

--[[
函数名：binstohexs
功能  ：二进制数据 转化为 16进制字符串格式，例如91688121364265f7 （表示第1个字节是0x91，第2个字节为0x68，......） -> "91688121364265f7"
参数  ：
		bins：二进制数据
		s：转换后，每两个字节之间的分隔符，默认没有分隔符
返回值：转换后的字符串
]]
function binstohexs(bins,s)
	local hexs = "" 

	if bins == nil or type(bins) ~= "string" then return nil,"nil input string" end

	for i=1,slen(bins) do
		hexs = hexs .. sformat("%02X",sbyte(bins,i)) ..(s==nil and "" or s)
	end
	hexs = string.upper(hexs)
	return hexs
end

--[[
函数名：hexstobins
功能  ：16进制字符串 转化为 二进制数据格式，例如"91688121364265f7" -> 91688121364265f7 （表示第1个字节是0x91，第2个字节为0x68，......）
参数  ：
		hexs：16进制字符串
返回值：转换后的数据
]]
function hexstobins(hexs)
	local tbins = {}
	local num

	if hexs == nil or type(hexs) ~= "string" then return nil,"nil input string" end

	for i=1,slen(hexs),2 do
		num = tonumber(ssub(hexs,i,i+1),16)
		if num == nil then
			return nil,"error num index:" .. i .. ssub(hexs,i,i+1)
		end
		tinsert(tbins,num)
	end

	return schar(unpack(tbins))
end

--[[
函数名：ucs2togb2312
功能  ：unicode小端编码 转化为 gb2312编码
参数  ：
		ucs2s：unicode小端编码数据
返回值：gb2312编码数据
]]
function ucs2togb2312(ucs2s)
	local cd = iconv.open("gb2312","ucs2")
	return cd:iconv(ucs2s)
end

--[[
函数名：gb2312toucs2
功能  ：gb2312编码 转化为 unicode小端编码
参数  ：
		gb2312s：gb2312编码数据
返回值：unicode小端编码数据
]]
function gb2312toucs2(gb2312s)
	local cd = iconv.open("ucs2","gb2312")
	return cd:iconv(gb2312s)
end

--[[
函数名：ucs2betogb2312
功能  ：unicode大端编码 转化为 gb2312编码
参数  ：
		ucs2s：unicode大端编码数据
返回值：gb2312编码数据
]]
function ucs2betogb2312(ucs2s)
	local cd = iconv.open("gb2312","ucs2be")
	return cd:iconv(ucs2s)
end

--[[
函数名：gb2312toucs2be
功能  ：gb2312编码 转化为 unicode大端编码
参数  ：
		gb2312s：gb2312编码数据
返回值：unicode大端编码数据
]]
function gb2312toucs2be(gb2312s)
	local cd = iconv.open("ucs2be","gb2312")
	return cd:iconv(gb2312s)
end

--[[
函数名：ucs2toutf8
功能  ：unicode小端编码 转化为 utf8编码
参数  ：
		ucs2s：unicode小端编码数据
返回值：utf8码数据
]]
function ucs2toutf8(ucs2s)
	local cd = iconv.open("utf8","ucs2")
	return cd:iconv(ucs2s)
end

--[[
函数名：utf8toucs2
功能  ：utf8编码 转化为 unicode小端编码
参数  ：
		utf8s：utf8编码数据
返回值：unicode小端编码数据
]]
function utf8toucs2(utf8s)
	local cd = iconv.open("ucs2","utf8")
	return cd:iconv(utf8s)
end

--[[
函数名：ucs2betoutf8
功能  ：unicode大端编码 转化为 utf8编码
参数  ：
		ucs2s：unicode大端编码数据
返回值：utf8编码数据
]]
function ucs2betoutf8(ucs2s)
	local cd = iconv.open("utf8","ucs2be")
	return cd:iconv(ucs2s)
end

--[[
函数名：utf8toucs2be
功能  ：utf8编码 转化为 unicode大端编码
参数  ：
		utf8s：utf8编码数据
返回值：unicode大端编码数据
]]
function utf8toucs2be(utf8s)
	local cd = iconv.open("ucs2be","utf8")
	return cd:iconv(utf8s)
end

--[[
函数名：utf8togb2312
功能  ：utf8编码 转化为 gb2312编码
参数  ：
		utf8s：utf8编码数据
返回值：gb2312编码数据
]]
function utf8togb2312(utf8s)
	local cd = iconv.open("ucs2","utf8")
	local ucs2s = cd:iconv(utf8s)
	cd = iconv.open("gb2312","ucs2")
	return cd:iconv(ucs2s)
end

--[[
函数名：gb2312toutf8
功能  ：gb2312编码 转化为 utf8编码
参数  ：
		gb2312s：gb2312编码数据
返回值：utf8编码数据
]]
function gb2312toutf8(gb2312s)
	local cd = iconv.open("ucs2","gb2312")
	local ucs2s = cd:iconv(gb2312s)
	cd = iconv.open("utf8","ucs2")
	return cd:iconv(ucs2s)
end

local function timeAddzone(y,m,d,hh,mm,ss,zone)

	if not y or not m or not d or not hh or not mm or not ss then
		return
	end

	hh = hh + zone
	if hh >= 24 then
		hh = hh - 24
		d = d + 1
		if m == 4 or m == 6 or m == 9 or m == 11 then
			if d > 30 then
				d = 1
				m = m + 1
			end
			elseif m == 1 or m == 3 or m == 5 or m == 7 or m == 8 or m == 10 then
			if d > 31 then
				d = 1
				m = m + 1
			end
			elseif m == 12 then
			if d > 31 then
				d = 1
				m = 1
				y = y + 1
			end
		elseif m == 2 then
			if (((y+2000)%400) == 0) or (((y+2000)%4 == 0) and ((y+2000)%100 ~=0)) then
				if d > 29 then
					d = 1
					m = 3
				end
			else
				if d > 28 then
					d = 1
					m = 3
				end
			end
		end
	end
	local t = {}
	t.year,t.month,t.day,t.hour,t.min,t.sec = y,m,d,hh,mm,ss
	return t
end
local function timeRmozone(y,m,d,hh,mm,ss,zone)
	if not y or not m or not d or not hh or not mm or not ss then
		return
	end
	hh = hh + zone
	if hh < 0 then
		hh = hh + 24
		d = d - 1
		if m == 2 or m == 4 or m == 6 or m == 8 or m == 9 or m == 11 then
			if d < 1 then
				d = 31
				m = m -1
			end
		elseif m == 5 or m == 7  or m == 10 or m == 12 then
			if d < 1 then
				d = 30
				m = m -1
			end
		elseif m == 1 then
			if d < 1 then
				d = 31
				m = 12
				y = y -1
			end
		elseif m == 3 then
			if (((y+2000)%400) == 0) or (((y+2000)%4 == 0) and ((y+2000)%100 ~=0)) then
				if d < 1 then
					d = 29
					m = 2
				end
			else
				if d < 1 then
					d = 28
					m = 2
				end
			end
		end
	end
	local t = {}
	t.year,t.month,t.day,t.hour,t.min,t.sec = y,m,d,hh,mm,ss
	return t
end

--[[
函数名：transftimezone
功能  ：当前时区的时间转换为新时区的时间
参数  ：
		y：当前时区年份
		m：当前时区月份
		d：当前时区天
		hh：当前时区小时
		mm：当前时区分
		ss：当前时区秒
		pretimezone：当前时区
		nowtimezone：新时区
返回值：返回新时区对应的时间，table格式{year,month.day,hour,min,sec}
]]
function transftimezone(y,m,d,hh,mm,ss,pretimezone,nowtimezone)
	local t = {}
	local zone = nil
	zone = nowtimezone - pretimezone

	if zone >= 0 and zone < 23 then
		t = timeAddzone(y,m,d,hh,mm,ss,zone)
	elseif zone < 0 and zone >= -24 then
		t = timeRmozone(y,m,d,hh,mm,ss,zone)
	end
	return t
end

