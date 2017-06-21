
require"pack"
module(...,package.seeall)

 --白底黑色为低电平 黑底白色为高电平

local GPIO_EVENT_DIR=1
local GPIO_EVENT_SET=2
local GPIO_EVENT_CHANGE=3

local GPIO_DIR_NOT_OPEN=0
local GPIO_DIR_OUTPUT=1
local GPIO_DIR_INPUT=2
local GPIO_DIR_INT=3

local evt_gpio,closing
local gpio = {}
--local piname = {}

local dlg = iup.dialog
{
	title = "GPIO",
	iup.vbox
	{
		iup.label{title="黑色背景表示高电平,白色背景表示低电平\nPX_XX O/I表示输出或者输入型管脚,输入管脚单击翻转状态"},
		iup.matrix
		{
			numcol = 4,
			numlin = 4,
			heightdef = 15,
			widthdef=40,
			id = "mat"
		}
	}
}

function openio(port,pin,dir)
	local gpioid = "P" .. port.."_"..pin

	if gpio[gpioid] then iup.Message("Error",gpioid .. "has opened!") return end

	if piname == nil then
		local path = string.match(set.get("luadb"),"(.*\\).+%..-$")
		local pinamefile = path .. "piname.lua"
		local f = io.open(pinamefile)

		if f then
			f:close()
			dofile(pinamefile)
		else
			piname = {}
		end
	else

	end

	local cellvalue = gpioid .. (dir == GPIO_DIR_OUTPUT and "O" or "I") .. "\n" .. (piname[gpioid] or "")

	for i=1,mat.numlin do
		for j=1,mat.numcol do
			if mat[i..":"..j] == nil then
				mat[i..":"..j] = cellvalue
				if piname[gpioid .. "_val"]  == 1 then
					mat["bgcolor"..i..":"..j] = "0 0 0"
					mat["fgcolor"..i..":"..j] = "255 255 255"
				end
				gpio[gpioid] = i..":"..j
				return i,j
			end
		end
	end

	mat.addlin = mat.numlin+1
	mat[mat.numlin..":1"] = cellvalue
	gpio[gpioid] = mat.numlin..":1"
	return mat.numlin,1
end

function closeio(port,pin)
	local gpioid = "P" .. port.."_"..pin

	if not gpio[gpioid] and not closing then --[[iup.Message("Error",gpioid .. "not exist!")]] return end

	mat[gpio[gpioid]] = nil
	gpio[gpioid] = nil
end

local function reverse(cell)
	if mat["bgcolor"..cell] == "255 255 255" then
		mat["bgcolor"..cell] = "0 0 0"
		mat["fgcolor"..cell] = "255 255 255"
	else
		mat["bgcolor"..cell] = "255 255 255"
		mat["fgcolor"..cell] = "0 0 0"
	end
	mat.redraw = "YES"
end

function setvalue(port,pin,v)
	if closing then return end
	local gpioid = "P" .. port.."_"..pin

	if not gpio[gpioid] and not closing then --[[iup.Message("Error",gpioid .. "not exist!")]] return end

	local cell = gpio[gpioid]
	--if cell==nil then return end
	local currval = mat["bgcolor"..cell] == "255 255 255" and 0 or 1

	if currval == v then return end

	reverse(cell)
end

function close()
	dlg:hide()
	mat["clearattrib"] = "ALL"
	for i=1,mat.numlin do
		for j=1,mat.numcol do
			mat[i..":"..j] = nil
		end
	end
	mat.numlin = 4
	mat.numcol = 4
	gpio = {}
end

function mat:click_cb(l,c)
	local cell = l..":"..c

	if not mat[cell] then return end

	local port,pin,dir = string.match(mat[cell],"P(%d+)_(%d+)([IO])")

	if dir ~= "I" then iup.Message("Error","It is not input pin!") return end

	port,pin,dir = tonumber(port),tonumber(pin),tonumber(dir)

	reverse(cell)

	local currval = mat["bgcolor"..cell] == "255 255 255" and 0 or 1

	evt_gpio:send(string.pack("bbbb",GPIO_EVENT_CHANGE,port,pin,currval))
end

function mat:edition_cb()
	return iup.IGNORE
end

local function proc_ctrl_evt(d)
	if d == "close" then
		closing = true
	end
end

--evt_ctrl = event.add(event.EVT_CTRL,proc_ctrl_evt)

local function proc_evt(d)
	local _,evt,port,pin,val = string.unpack(d,"bbbb")
	local l,c

	--iup.Message("debug",evt..port..pin..val)
	--print(string.byte(d,1,-1))
	--print(evt,port,pin,val)

	if evt == GPIO_EVENT_DIR then
		if val == GPIO_DIR_NOT_OPEN then
			closeio(port,pin)
		else
			openio(port,pin,val)
		end
		mat.redraw = "YES"
		if dlg.visible == "NO" then
			dlg:show()
		end
	elseif evt == GPIO_EVENT_SET then
		setvalue(port,pin,val)
		mat.redraw = "YES"
	end
end

evt_gpio = event.add(event.EVT_GPIO,proc_evt)


