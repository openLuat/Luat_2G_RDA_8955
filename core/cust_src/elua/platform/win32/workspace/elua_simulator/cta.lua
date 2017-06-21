print(_INTERNAL_VERSION)

local putext = disp.puttext
local state = 0 -- 话机状态: 0:开机中 1:idle 2:关机中
local onofftone = "AT+AMRT=1,1,0"
local msg,imei,currcmd = nil
local callexist = 4
local lastcallnumber = ""
local callvol = 6
local blstatus = 0
local simready = false
local cmds ={
	"ATE0",
	"ATI",
	"AT*BTIME",
	"AT+CGSN",
	"AT+CHFA=0",
	"AT+CALM=0",
	"AT+CRSL=100",
	"AT+CLIP=1",
	"AT+CREG=2",
}

local currwin = ""

local keytab = {[0+2] = "dad",[0+0] = "mum", [4+1] = "home", [4+0] = "school",[0+1] = "sos"}

local soslist = { -- sos界面下的紧急号码选择
	dad = "112",
	mum = "120",
	home = "119",
	school = "110",
	sos = "122",
}

local dialist = { -- 快捷拨号列表
	dad = "10086",
	mum = "10086",
	home = "10086",
	school = "10086",
}

function lcd_init()
	local lcd_param ={
		width = 128,
		height = 128,
		bpp = 16,
		yoffset = 32,
		bus = disp.BUS_SPI4LINE,
		pinrst = pio.P0_16,
		initcmd = {
			0x00020011,
			0x00010078,
			0x000200B1,
			0x00030002,
			0x00030035,
			0x00030036,
			0x000200B2,
			0x00030002,
			0x00030035,
			0x00030036,
			0x000200B3,
			0x00030002,
			0x00030035,
			0x00030036,
			0x00030002,
			0x00030035,
			0x00030036,
			0x000200B4,
			0x00030003,
			0x000200C0,
			0x000300A2,
			0x00030002,
			0x00030084,
			0x000200C1,
			0x000300C5,
			0x000200C2,
			0x0003000D,
			0x00030000,
			0x000200C3,
			0x0003008D,
			0x0003002A,
			0x000200C4,
			0x0003008D,
			0x000300EE,
			0x000200C5,
			0x00030003,
			0x00020036,
			0x000300C8,
			0x000200E0,
			0x00030012,
			0x0003001C,
			0x00030010,
			0x00030018,
			0x00030033,
			0x0003002C,
			0x00030025,
			0x00030028,
			0x00030028,
			0x00030027,
			0x0003002F,
			0x0003003C,
			0x00030000,
			0x00030003,
			0x00030003,
			0x00030010,
			0x000200E1,
			0x00030012,
			0x0003001C,
			0x00030010,
			0x00030018,
			0x0003002D,
			0x00030028,
			0x00030023,
			0x00030028,
			0x00030028,
			0x00030026,
			0x0003002F,
			0x0003003B,
			0x00030000,
			0x00030003,
			0x00030003,
			0x00030010,
			0x0002003A,
			0x00030005,
			0x00020029,
		},
		sleepcmd = {
			0x00020010
		},
		wakecmd = {
			0x00020011
		},
	}

	disp.init(lcd_param)
	disp.clear()
	disp.update()
end

function device_init()
	pmd.sleep(0)
	rtos.init_module(rtos.MOD_KEYPAD, 0, 0x07, 0x11)
	uart.setup(uart.ATC, 0, 0, uart.PAR_NONE, uart.STOP_1)
	lcd_init()
	setbl(1)
end

function send_at(command)
	if currcmd then -- last cmd not end
		table.insert(cmds,command)
		return false
	end
	print("send:",command)
	currcmd = command
	uart.write(uart.ATC, command .. "\r")
	return true
end

function receive_at(atcrsp)
	if string.len(atcrsp) == 0 then return end
	print("recv:",atcrsp)
	if currcmd == "AT+CGSN" and not imei and string.len(atcrsp) > 15 then
		local i,j = string.find(atcrsp, "(%d+)")
		if i ~= nil then
			local s = string.sub(atcrsp, i, j)
			if string.len(s) == 15 then imei = s
			else print("warning: get imei",s)
			end
		end
	end -- cgsn
	if string.find(atcrsp, "OK") then
		if currcmd == "ATA" then callexist = 3 end
		currcmd = nil
	elseif string.find(atcrsp, "ERROR") then
		currcmd = nil
	elseif string.find(atcrsp, "NO DIALTONE") or string.find(atcrsp, "NO ANSWER") then
		discwin()
		currcmd = nil callexist = 0
		idlewin()
	elseif string.find(atcrsp, "NO CARRIER") then
		discwin()
		callexist = 0
		idlewin()
	elseif string.find(atcrsp, "RING") then
		callexist = 2
	elseif string.find(atcrsp, "%+CLIP:") then
		incomingcall(string.match(atcrsp,"%+CLIP: \"(%d+)\""))
	elseif string.find(atcrsp, "CONNECT") then
		callexist = 3
	elseif string.find(atcrsp, "+CPIN: READY") then
		rtos.timer_start(3,6000)
		simready = true
		callexist = 0
	elseif string.find(atcrsp, "+CPIN: NOT INSERTED") then
		rtos.timer_start(2, 2000)
	end
end

-- makecall
function incomingcall(num)
	incallwin(num)
	--send_at("AT+AMRT=1,1,1")
	answer()
end

function dial(num,isos)
	print("dial:",callexist,num)

	if callexist ~= 0 then
		print("callexist: ",lastcallnumber) return
	end

	local cnum = num

	if isos == true then
		cnum = "112"
	end

	if send_at("ATD" .. cnum .. ";") then
		lastcallnumber = num callexist = 1
		callwin(num)
	end
end

function answer()
	if callexist ~= 2 then return end

	send_at("ATA")
end

-- end call
function hangup()
	if callexist == 0 or callexist == 4 then return end
	send_at("ATH")
	discwin()
	callexist = 0
	idlewin()
end

function adjustvol(updown)
	local vol = nil

	if updown then callvol = callvol+1
	else callvol = callvol-1
	end

	if callvol > 10 then callvol = 10 end
	if callvol < 0 then callvol = 0 end

	vol = callvol*10
	send_at("at+clvl=" .. vol)
end

-- msg process
function handletimer(timerid)
	print("timeout: ",timerid)
	if timerid == 1 then
		state = 2
		rtos.timer_start(3,3000)
		send_at(onofftone)
	elseif timerid == 2 then
		callexist = 0
	elseif timerid == 3 then
		send_at("AT+AMRT=0")
		if state == 0 then
			state = 1
			idlewin()
		elseif state == 2 then
			rtos.poweroff()
		else
			print("state:error",state)
		end
	elseif timerid == 4 then
		setbl(0)
	elseif timerid == 5 then
		send_at("AT+CSQ")
		rtos.timer_start(5,3000)
	end
end

function handlekey(pressed,row,col)
	if state ~= 1 then return end
	if not pressed then
		rtos.timer_stop(1) return
	end
	print("key: ",row,col)
	setbl(1)
	if row == 255 and col == 255 then
		if callexist ~= 0 then
			hangup()
		else
			idlewin()
		end
		rtos.timer_start(1, 3000)
	else
		rtos.timer_stop(1)

		local key = keytab[row+col]

		if callexist == 0 then
			if currwin == "soswin" then
				if not simready then
					dial(soslist[key],true)
				else
					dial(soslist[key])
				end
			else
				if key == "sos" then
					soswin()
				else
					dial(dialist[key])
				end
			end
		elseif callexist == 2 then answer()
		elseif callexist == 3 or callexist == 1 then
			if key == "mum" then adjustvol(true)
			elseif key == "school" then adjustvol(false)
			end
		end
	end
end

function handleat()
	local s = nil
	repeat
		s = uart.read(uart.ATC, "*l", 0)
		receive_at(s)
	until string.len(s) == 0
end

-- idlewin
function idlewin()
	currwin = "idlewin"
	disp.clear()
	putext("IMEI:",48,32)
	putext(imei,4,48)
	putext("HW:V1.0.0",28,64)
	putext("SW:V1.0.0",28,80)
	disp.update()
end

function callwin(num)
	currwin = "callwin"
	disp.clear()
	putext("CALLING",30,32)
	putext(num,4,48)
	disp.update()
end

function incallwin(num)
	if currwin == "incallwin" then return end
	currwin = "incallwin"
	disp.clear()
	putext("INCOMING",30,32)
	putext(num,4,48)
	disp.update()
end

function soswin()
	currwin = "soswin"
	disp.clear()
	putext("SOS LIST:",28,16)
	putext("112",48,32)
	putext("120",48,48)
	putext("119",48,64)
	putext("110",48,80)
	putext("122",48,96)
	disp.update()
end

function discwin()
	currwin = "discwin"
	dispstr("CALL DISCONNECT")
	rtos.sleep(1500)
end

function startwin()
	currwin = "startwin"
	dispstr("STARTING")
end

function dispstr(str)
	disp.clear()
	putext(str,4,48)
	disp.update()
end

function setbl(onoff)
	if onoff ~= blstatus then
		blstatus = onoff
		pmd.ldoset(blstatus, pmd.LDO_KEYPAD, pmd.LDO_LCD)
	end

	if onoff == 1 then
		rtos.timer_start(4,15000)
	end
end

device_init()
startwin()
rtos.timer_start(3,5000)
send_at(onofftone)
rtos.timer_start(5,3000)

while true do
	msg = rtos.receive(rtos.INF_TIMEOUT)

	if msg.id == rtos.MSG_UART_RXDATA then
		if msg.uart_id == uart.ATC then
			handleat()
			if not currcmd then
				if #cmds > 0 then
					send_at(table.remove(cmds,1))
				end
			end
		end
	elseif msg.id == rtos.MSG_KEYPAD then
		handlekey(msg.pressed, msg.key_matrix_row, msg.key_matrix_col)
	elseif msg.id == rtos.MSG_TIMER then
		handletimer(msg.timer_id)
	end
end
