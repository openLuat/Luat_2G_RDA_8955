require"config"
require"nvm"
module(...,package.seeall)

--[[
功能需求：
测试config.lua中4个参数
每次参数内容发生改变后，都会打印出所有参数
]]

local function print(...)
	_G.print("test",...)
end

local function getTablePara(t)
	if type(t)=="table" then
		local ret = "{"
		for i=1,#t do
			ret = ret..t[i]..(i==#t and "" or ",")
		end
		ret = ret.."}"
		return ret
	end
end

local function printAllPara()
	_G.print("\r\n\r\n")
	print("---printAllPara begin---")
	_G.print("strPara = "..nvm.get("strPara"))
	_G.print("numPara = "..nvm.get("numPara"))
	_G.print("boolPara = "..tostring(nvm.get("boolPara")))
	_G.print("tablePara = "..getTablePara(nvm.get("tablePara")))
	print("---printAllPara end  ---\r\n\r\n")
end

local function restoreFunc()
	print("restoreFunc")
	nvm.restore()
	printAllPara()
end

local function paraChangedInd(k,v,r)
	print("paraChangedInd",k,v,r)
    printAllPara()
	return true
end

local function tParaChangedInd(k,kk,v,r)
	print("tParaChangedInd",k,kk,v,r)
    printAllPara()
	return true
end

local procer =
{
	PARA_CHANGED_IND = paraChangedInd, --调用nvm.set接口修改参数的值，如果参数的值发生改变，nvm.lua会调用sys.dispatch接口抛出PARA_CHANGED_IND消息
	TPARA_CHANGED_IND = tParaChangedInd,	--调用nvm.sett接口修改table类型的参数中的某一项的值，如果值发生改变，nvm.lua会调用sys.dispatch接口抛出TPARA_CHANGED_IND消息
}
--注册消息处理函数
sys.regapp(procer)

--初始化参数管理模块
nvm.init("config.lua")

--打印出所有参数
printAllPara()

--修改strPara参数值为str2，修改后，nvm.lua会调用sys.dispatch接口抛出PARA_CHANGED_IND消息，test.lua应该处理PARA_CHANGED_IND消息调用paraChangedInd(请注意观察paraChangedInd中打印出的k,v,r)，自动打印出所有参数
nvm.set("strPara","str2","strPara2")
--修改strPara参数值为str3，修改后，虽然strPara的值变成了str3，但是nvm.lua不会抛出PARA_CHANGED_IND消息
--因为调用nvm.set时没有传入第三个参数
--nvm.set("strPara","str3")
sys.timer_start(nvm.set,1000,"strPara","str3")

--修改numPara参数值为2，修改后，nvm.lua会调用sys.dispatch接口抛出PARA_CHANGED_IND消息，test.lua应该处理PARA_CHANGED_IND消息调用paraChangedInd(请注意观察paraChangedInd中打印出的k,v,r)，自动打印出所有参数
--nvm.set("numPara",2,"numPara2",false)
sys.timer_start(nvm.set,2000,"numPara",2,"numPara2",false)
--nvm.set("numPara",3,"numPara3",false)
sys.timer_start(nvm.set,3000,"numPara",3,"numPara3",false)
--nvm.set("numPara",4,"numPara4",false)
sys.timer_start(nvm.set,4000,"numPara",4,"numPara4",false)
--执行上面3条nvm.set语句后，numPara的值最终变成了4，但是是内存中变成了4，文件中存储的实际上还是1，执行下面的一条语句后，才会去写文件系统
nvm.flush()
--也就是说nvm.set中的第4个参数控制是否写入文件系统（false不写入文件系统，其余都写入文件系统），目的是如果连续设置很多参数，可以减少写文件的次数

--同nvm.set("strPara","str2","strPara2")，原理相似
--nvm.set("tablePara",{"item2-1","item2-2","item2-3"},"tablePara2")
sys.timer_start(nvm.set,5000,"tablePara",{"item2-1","item2-2","item2-3"},"tablePara2")
--只修改tablePara中的第2项为item3-2
--nvm.sett("tablePara",2,"item3-2","tablePara3")
sys.timer_start(nvm.sett,6000,"tablePara",2,"item3-2","tablePara3")

--恢复出厂设置,打印出所有参数
sys.timer_start(restoreFunc,9000)
