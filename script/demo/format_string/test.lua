module(...,package.seeall)--所有程序可见
--[[数据格式转换demo
    数值，二进制数，字符--]]
require "common"--利用了库中的common

require"common"


--[[函数名：bittese
    功能：介绍bit库的使用，并打印出来
    返回值：无--]]
local function bittest()
	print("bittest:")      --程序运行开始标记
	print(bit.bit(2))--参数是位数，作用是1向左移动两位，打印出4
	
	print(bit.isset(5,0))--第一个参数是是测试数字，第二个是测试位置。从右向左数0到7。是1返回true，否则返回false，该返回true
	print(bit.isset(5,1))--打印false
	print(bit.isset(5,2))--打印true
	print(bit.isset(5,3))--返回返回false
	
	print(bit.isclear(5,0))--与上面的相反
	print(bit.isclear(5,1))
	print(bit.isclear(5,2))
	print(bit.isclear(5,3))
	
	print(bit.set(0,0,1,2,3))--在相应的位数置1，打印15
	
    print(bit.clear(5,0,2)) --在相应的位置置0，打印0
	
	print(bit.bnot(5))--按位取反
	
	print(bit.band(1,1))--与,--输出1
	
	print(bit.bor(1,2))--或，--输出3
	
	print(bit.bxor(1,2))--异或,相同为0，不同为1
	
	print(bit.lshift(1,2))--逻辑左移，“100”，输出为4
	
	print(bit.rshift(4,2))--逻辑右移，“001”，输出为1 
	
	print(bit.arshift(2,2))--算数右移，左边添加的数与符号有关，输出为0
  
end




--[[函数名：packedtest
    功能：扩展库pack的功能演示
    参数：无
    返回值：无
    --]]
local function packedtest()
	--[[将一些变量按照格式包装在字符串.'z'有限零字符串，'p'长字节优先，'P'长字符优先，
	'a'长词组优先，'A'字符串型，'f'浮点型,'d'双精度型,'n'Lua 数字,'c'字符型,'b'无符号字符型,'h'短型,'H'无符号短型
	'i'整形,'I'无符号整形,'l'长符号型,'L'无符号长型]]
	print("pcak.pack test：")
	print(common.binstohexs(pack.pack("H",100)))--当"100"以字符串形式包装时，会打印出“0064”
	print(common.binstohexs(pack.pack("h",100)))--当"100"以整数形式包装时，会打印出“0064”
	print(pack.pack("A","LUAT"))
	print("pack.unpack test:")
	nextpox1,val1,val2,val3,val4=pack.unpack("luat100","c4")--"nextpos"下个待解析的位置	
	print(nextpox1,val1,val2,val3,val4)        --分别对应的是"l","u","a","t"的ascii码数据
	print(string.char(val1,val2,val3,val4))    --将ascii码数据转化为字符输出
	nextpox2,string1=pack.unpack("luat100","A4")--输出“luat”
	print(nextpox2,string1)
	nextpox3,number1,number2=pack.unpack(common.hexstobins("006400000064"),">H>i")--[[输出无符号短型和整形,因为无符号短型是四个字节
	整形是8个字节,输出为100,100--]]
	print(nextpox3,number1,number2)
	nextpox3,number1=pack.unpack(common.hexstobins("0064"),">h")--输出为100，因为短型是四个字节
    print(nextpox3,number1)
end

--[[短整型  占4个字节
    长整型 占用8个字节（64位）
    double型 占8个字节
    long double型 占16个字节
 
    数据类型	取值范围
    整型 [signed]int	-2147483648~+2147483648
    无符号整型unsigned[int]	0~4294967295
    短整型 short [int]	-32768~32768
    无符号短整型unsigned short[int]	0~65535
    长整型 Long int	-2147483648~+2147483648
    无符号长整型unsigned [int]	0~4294967295
    字符型[signed] char	-128~+127
    无符号字符型 unsigned char	0~255 
	不支持小数类型 --]]

--[[函数名：stringtest
    功能：sting库几个接口的使用演示
    参数：无
    返回值：无--]]
	
	
local function stringtest()
	print("stringtest:")
	print(string.char(97,98,99))--将相应的数值转化为字符
	print(string.byte("abc"),2) --第一个参数是字符串，第二个参数是位置。功能是：将字符串中所给定的位置转化为数值
	local i=100
	local string1="luat great"
	print(string.format("%04d//%s",i,string1))--[[指示符后的控制格式的字符可以为：十进制'd'；十六进制'x'
	八进制'o'；浮点数'f'；字符串's',控制格式的个数与后面的参数个数一致。功能：按照特定格式输出参数。--]]
	print(string.gsub("luat is","is","great"))--第一个参数是目标字符串，第二个参数是标准字符串，第三个是待替换字符串
	--打印出"luat great"
end



--[[函数名：bitstohexs()
   功能：将二进制数字转化为十六进制，并输出转换后的十六进制数字串，每个字节之间用分隔符隔开
   打印出十六进制数字串
   参数：第一个参数二进制数字，第二个是分隔符
   返回值：          --]]

local function binstohexs(binstring,s)
	
	hexs=common.binstohexs(binstring,s) --调用了基本库中的common库
	print(hexs)                   --输出十六进制数字串	
end 



	
--[[函数名： hexstobits
    功能：将十六进制数转换为二进制数，并储存在数组中,输出转化后的二进制数
	参数：十六进制数
	返回值：                           --]]
local function hexstobins(hexstring)--将十六进制数字转化为二进制
	print(common.hexstobins(hexstring)) --注意二进制中有些是可打印可见的，有些则不是
end





--[[
函数名：ucs2togb2312
功能  ：unicode小端编码 转化为 gb2312编码,并打印出gd2312编码数据
参数  ：
		ucs2s：unicode小端编码数据,注意输入参数的字节数
返回值：
]]
local function ucs2togb2312(ucs2s)
	print("ucs2togb2312")	
	local gd2312num=common.ucs2togb2312(ucs2s)--调用的是common.ucs2togb2312，返回的是编码所对应的字符串
	print("gb2312  code："..gd2312num)	
end





--[[
函数名：gb2312toucs2
功能  ：gb2312编码 转化为 unicode十六进制小端编码数据并打印
参数  ：
		gb2312s：gb2312编码数据，注意输入参数的字节数
返回值：
]]
local function gb2312toucs2(gd2312num)
	print("gb2312toucs2")
	local ucs2num=common.gb2312toucs2(gd2312num)
	print("unicode little-endian code:"..common.binstohexs(ucs2num))--要将二进制转换为十六进制，否则无法输出
end 





--[[
函数名：ucs2betogb2312
功能  ：unicode大端编码 转化为 gb2312编码，并打印出gb2312编码数据,
大端编码数据是与小端编码数据位置调换
参数  ：
		ucs2s：unicode大端编码数据，注意输入参数的字节数
返回值：
]]
local function ucs2betogb2312(ucs2s)
	print("ucs2betogb2312")
	local gd2312num=common.ucs2betogb2312(ucs2s) --转化后的数据直接变成字符可以直接输出 
	print("gd2312 code ："..gd2312num)	
end



--[[
函数名：gb2312toucs2be
功能  ：gb2312编码 转化为 unicode大端编码，并打印出unicode大端编码
参数  ：
		gb2312s：gb2312编码数据，注意输入参数的字节数
返回值：unicode大端编码数据
]]
function gb2312toucs2be(gb2312s)
	print("gb2312toucs2be")
    local ucs2benum=common.gb2312toucs2be(gb2312s)
	print("unicode big-endian code :"..common.binstohexs(ucs2benum))
end


	
--[[
函数名：ucs2toutf8
功能  ：unicode小端编码 转化为 utf8编码,并打印出utf8十六进制编码数据
参数  ：
		ucs2s：unicode小端编码数据，注意输入参数的字节数
返回值：
]]
local function ucs2toutf8(usc2)
	print("ucs2toutf8")
	local utf8num=common.ucs2toutf8(usc2)
	print("utf8  code："..common.binstohexs(utf8num))
	
end





--[[
函数名：utf8togb2312
功能  ：utf8编码 转化为 gb2312编码,并打印出gb2312编码数据
参数  ：
		utf8s：utf8编码数据，注意输入参数的字节数
返回值：
]]
local function utf8togb2312(utf8s)
	print("utf8togb2312")
	local gb2312num=common.utf8togb2312(utf8s)
	print("gd2312 code："..gb2312num)
	
end




--[[ 函数调用--]]

bittest()
packedtest()
stringtest()





--[[测试程序，接口举例，用模拟器就可以直接测试,以“我”为例--]]

binstohexs("ab")
hexstobins("3132")

ucs2togb2312(common.hexstobins("1162"))  --"1162"是"我"字的ucs2编码，这里调用了common.hexstobins将参数转化为二进制，也就是两个字节。
gb2312toucs2(common.hexstobins("CED2")) --"CED2"是"我"字的gb22312编码  
ucs2betogb2312(common.hexstobins("6211"))--"6211"是"我"字的ucs2be编码
gb2312toucs2be(common.hexstobins("CED2"))
ucs2toutf8(common.hexstobins("1162"))
utf8togb2312(common.hexstobins("E68891"))--"E68891"是"我"字的utf8编码




















