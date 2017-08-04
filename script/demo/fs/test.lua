module(...,package.seeall)--所有程序可见

--[[该demo提供四种接口，第一种readfile(filename)读文件，第二种writevala(filename,value)，写文件内容，附加模式，
第三种function writevalw(filename,value)，写文件内容，覆盖模式，第四种deletefile(filename)，删除文件。--]]

--[[
    函数名：readfile(filename)
	功能：打开所输入文件名的文件，并输出储存在里面额内容
	参数：文件名
	返回值：无                     ]]
local function readfile(filename)--打开指定文件并输出内容
	
    local filehandle=io.open(filename,"r")--第一个参数是文件名，第二个是打开方式，'r'读模式,'w'写模式，对数据进行覆盖,'a'附加模式,'b'加在模式后面表示以二进制形式打开
	if filehandle then          --判断文件是否存在
	    local fileval=filehandle:read("*all")--读出文件内容
	  if  fileval  then
	       print(fileval)  --如果文件存在，打印文件内容
		   filehandle:close()--关闭文件
	  else 
	       print("文件为空")--文件不存在
	  end
	else 
	    print("文件不存在或文件输入格式不正确") --打开失败  
	end 
	
end



--[[
    函数名： writevala(filename,value)
	功能：向输入的文件中添加内容，内容附加在原文件内容之后
	参数：第一个文件名，第二个需要添加的内容
	返回值：无                         --]]
local function writevala(filename,value)--在指定文件中添加内容,函数名最后一位就是打开的模式
	local filehandle = io.open(filename,"a+")--第一个参数是文件名，后一个是打开模式'r'读模式,'w'写模式，对数据进行覆盖,'a'附加模式,'b'加在模式后面表示以二进制形式打开
	if filehandle then
	    filehandle:write(value)--写入要写入的内容
	    filehandle:close()
	else
	    print("文件不存在或文件输入格式不正确") --打开失败  
	end
end



--[[
    函数名：writevalw(filename,value)
	功能：向输入文件中添加内容，新添加的内容会覆盖掉原文件中的内容
	参数：同上
	返回值：无                 --]]
local function writevalw(filename,value)--在指定文件中添加内容
	local filehandle = io.open(filename,"w")--第一个参数是文件名，后一个是打开模式'r'读模式,'w'写模式，对数据进行覆盖,'a'附加模式,'b'加在模式后面表示以二进制形式打开
	if filehandle then
	    filehandle:write(value)--写入要写入的内容
	    filehandle:close()
	else
	    print("文件不存在或文件输入格式不正确") --打开失败  
	end
end


--[[函数名：deletefile(filename)
    功能：删除指定文件中的所有内容
	参数：文件名
	返回值：无             --]]
local function deletefile(filename)--删除指定文件夹中的所有内容
	local filehandle = io.open(filename,"w")
	if filehandle then
	    filehandle:write()--写入空的内容
	    print("删除成功")
		filehandle:close()
	else
	    print("文件不存在或文件输入格式不正确") --打开失败  
	end
end



readfile("/3.txt")

writevala("/3.txt","great")

readfile("/3.txt")
writevalw("/3.txt","great")
readfile("/3.txt")

deletefile("/3.txt")
readfile("/3.txt")
