
require"iuplua"
require "iupluacontrols"
dofile"iupid.lua"

require"set"

dlg = iup.dialog
{
	iup.vbox
	{
		iup.label{title="执行文件", id="label_luadb"},
		iup.hbox
		{
			iup.text{expand="YES", id="text_luadb"},
			iup.button{title="浏览", id="btn_browse"},
		},
		iup.hbox
		{
			iup.label{title="串口配置",id="label_uartset"},
			iup.fill{},
			iup.button{title="刷新端口",id="btn_rcom"},
		},
		iup.hbox
		{
			iup.label{expand="HORIZONTAL", title="ATC", id="label_uartatc"},
			iup.fill{},
			iup.list{size="80x",dropdown="YES",id="list_atc"},
		},
		iup.hbox
		{
			iup.label{expand="HORIZONTAL", title="UART1", id="label_uart1"},
			iup.fill{},
			iup.list{size="80x",dropdown="YES",id="list_uart1"},
		},
		iup.hbox
		{
			iup.label{expand="HORIZONTAL", title="UART2", id="label_uart2"},
			iup.fill{},
			iup.list{size="80x",dropdown="YES",id="list_uart2"},
		},
		iup.hbox
		{
			iup.label{expand="HORIZONTAL", title="HOST", id="label_host"},
			iup.fill{},
			iup.list{size="80x",dropdown="YES",id="list_host"},
		},
		iup.hbox
		{
			iup.button{title="OK",size="50x",id="btn_ok"},
			iup.fill{},
			iup.button{title="CANCEL",size="50x",id="btn_cancel"},
		},
	}
	;title = "配置",size = "200x", margin = "10x10", resize = "NO", maxbox = "NO", minbox = "NO"
}

text_luadb.value = set.get("luadb")

local param = {}
param.uart = {unpack(set.get("uart"))}

function btn_browse:action()
	filedlg = iup.filedlg{dialogtype = "SELECT", title = "选择luadb文件",
						  filter = "*.bin;*.lua", filterinfo = "lua or luadb files",
						  directory=set.get("luadb")}

	-- Shows file dialog in the center of the screen
	filedlg:popup (iup.ANYWHERE, iup.ANYWHERE)

	if filedlg.status == "0" then
		param.luadb = filedlg.value
		text_luadb.value = filedlg.value
	end

	return iup.DEFAULT
end

function btn_ok:action()
	param.go = 1
	for k,v in pairs(param) do
		if type(v) == "table" then
			for k_,v_ in pairs(v) do
				set.set(k,k_,v_)
			end
		else
			set.set(k,v)
		end
	end
	--os.execute("lst_to_cap.exe")--
	--dlg:hide()
	--os.execute("..\\elua\\elua_simulator.exe "..string.gsub(set.get("luadb"),"(\\)","%0%0"))
	--os.execute("dir")
	--print("after os dir")
	io.popen("..\\elua\\elua_simulator.exe "..string.gsub(set.get("luadb"),"(\\)","%0%0"),"w")
	--io.popen("svn help")
	return iup.DEFAULT
end

function btn_cancel:action()
	set.set("go",0)
	return iup.CLOSE
end

local coms = {}
local function getcoms()
	local h = io.popen([[reg query "HKEY_LOCAL_MACHINE\Hardware\DeviceMap\SerialComm"]])
	coms = {}

	for s in h:lines() do
		s = string.match(s,"(COM%d+)")

		if s then table.insert(coms,s) end
	end
end

local listuarts = {list_atc,list_uart1,list_uart2,list_host}

local function upcoms()
	getcoms()
	local comv
	for j,lid in ipairs(listuarts) do
		comv = param.uart[j]
		for i,cid in ipairs(coms) do
			lid[i] = cid
			if comv == cid then
				lid.value = i
			end
		end
		lid.visible_items = #coms
	end

	for j,lid in ipairs(listuarts) do
		lid.visible_items = #coms
	end
end

function btn_rcom:action()
	upcoms()
end

function list_atc:action(t,i,v)
	--iup.Message("test", tostring(t)..type(i)..i..type(v)..v)
	if v == 1 then
		param.uart[1] = t
	end
	return iup.DEFAULT
end

function list_uart1:action(t,i,v)
	if v == 1 then
		param.uart[2] = t
	end
	return iup.DEFAULT
end

function list_uart2:action(t,i,v)
	if v == 1 then
		param.uart[3] = t
	end
	return iup.DEFAULT
end

function list_host:action(t,i,v)
	if v == 1 then
		param.uart[4] = t
	end
	return iup.DEFAULT
end

local count = 0
function idle_cb()
	if hsimu then
		count = count + 1
		--if count <= 1 then
			--print("hello")
			--iup.Message("debug",hsimu:read("*a"))
		--end
	end
end

upcoms()
iup.SetIdle(idle_cb)
dlg:show()

iup.MainLoop()
