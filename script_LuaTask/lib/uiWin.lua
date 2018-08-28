--- 模块功能：UI窗口管理
-- @module uiWin
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.25

module(...,package.seeall)

--窗口管理栈
local stack = {}
--当前分配的窗口ID
local winid = 0

local function allocid()
	winid = winid + 1
	return winid
end

local function loseFocus()
	if stack[#stack] and stack[#stack]["onLoseFocus"] then
		stack[#stack]["onLoseFocus"]()
	end	
end

--- 新增一个窗口
-- @table wnd，窗口的元素以及消息处理函数表
-- @return number，窗口ID
-- @usage uiWin.add({onUpdate = refresh})
function add(wnd)
	---必须注册更新接口
	assert(wnd.onUpdate)
	if type(wnd) ~= "table" then
		assert("unknown uiwin type "..type(wnd))
	end
	--上一个窗口执行失去焦点的处理函数
	loseFocus()
	--为新窗口分配窗口ID
	wnd.id = allocid()
	--新窗口请求入栈
	sys.publish("UIWND_ADD",wnd)
	return wnd.id
end

--- 移除一个窗口
-- @number winId，窗口ID
-- @return nil
-- @usage uiWin.remove(winId)
function remove(winId)
	sys.publish("UIWND_REMOVE",winId)
end

function removeAll()
    sys.publish("UIWND_REMOVEALL")
end

function update()
    sys.publish("UIWND_UPDATE")
end

local function onAdd(wnd)
	table.insert(stack,wnd)
	stack[#stack].onUpdate()
end

local function onRemove(winid)
	local istop,k,v
	for k,v in ipairs(stack) do
		if v.id == winid then
			istop = (k==#stack)
			table.remove(stack,k)
			if #stack~=0 and istop then
				stack[#stack].onUpdate()
			end
			return
		end
	end
end

local function onRemoveAll()
	local k,v
	for k,v in ipairs(stack) do
		table.remove(stack,k)
	end
end

local function onUpdate()
    if stack[#stack] and stack[#stack].onUpdate then
        stack[#stack].onUpdate()
    end
end

--key：自定义功能键
--value：自定义功能键的状态
local function onKey(key,value)
    if stack[#stack] and stack[#stack].onKey then
        stack[#stack].onKey(key,value)
    end
end

--- 判断一个窗口是否处于最前显示
-- @number winId，窗口ID
-- @return bool，true表示最前显示，其余表示非最前显示
-- @usage uiWin.isActive(winId)
function isActive(winId)
    if stack[#stack] and stack[#stack].id then
        return stack[#stack].id==winId
    end	
end

sys.subscribe("UIWND_ADD",onAdd)
sys.subscribe("UIWND_REMOVE",onRemove)
sys.subscribe("UIWND_REMOVEALL",onRemoveAll)
sys.subscribe("UIWND_UPDATE",onUpdate)
sys.subscribe("UIWND_TOUCH",onTouch)
sys.subscribe("UIWND_KEY",onKey)
