--[[
模块名称：UI窗口管理
模块功能：窗口的新增、删除、刷新等
模块最后修改时间：2017.07.26
]]
local base = _G
local sys = require"sys"
local table = require"table"
local print,assert,type,ipairs = base.print,base.assert,base.type,base.ipairs
module(...)

--窗口管理栈
local stack = {}
--当前分配的窗口ID
local winid = 0

local function allocid()
	winid = winid + 1
	return winid
end

local function losefocus()
	if stack[#stack] and stack[#stack]["onlosefocus"] then
		stack[#stack]["onlosefocus"]()
	end	
end

--[[
函数名：add
功能  ：新增一个窗口
参数  ：
		wnd：窗口的元素以及消息处理函数表
返回值：窗口ID
]]
function add(wnd)
	---必须注册更新接口
	assert(wnd.onupdate)
	if type(wnd) ~= "table" then
		assert("unknown uiwin type "..type(wnd))
	end
	--上一个窗口执行失去焦点的处理函数
	losefocus()
	--为新窗口分配窗口ID
	wnd.id = allocid()
	--新窗口请求入栈
	sys.dispatch("UIWND_ADD",wnd)
	return wnd.id
end

--[[
函数名：remove
功能  ：移除一个窗口
参数  ：
		winid：窗口ID
返回值：无
]]
function remove(winid)
	sys.dispatch("UIWND_REMOVE",winid)
end

local function onadd(wnd)
	table.insert(stack,wnd)
	stack[#stack].onupdate()
end

local function onremove(winid)
	local istop,k,v
	for k,v in ipairs(stack) do
		if v.id == winid then
			istop = (k==#stack)
			table.remove(stack,k)
			if #stack~=0 and istop then
				stack[#stack].onupdate()
			end
			return
		end
	end
end

local function onupdate()
	stack[#stack].onupdate()
end

--[[
函数名：isactive
功能  ：判断一个窗口是否处于最前显示
参数  ：
		winid：窗口ID
返回值：true表示最前显示，其余表示非最前显示
]]
function isactive(winid)
	return stack[#stack].id==winid
end

 sys.regapp({
 	UIWND_ADD = onadd,
 	UIWND_REMOVE = onremove,
 	UIWND_UPDATE = onupdate,
 	UIWND_TOUCH = onTouch,
 	UIWND_KEY = onKey,
 })
