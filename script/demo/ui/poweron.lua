require"light"
module(...,package.seeall)
local appid,appid1,typ

local function print(...)
	_G.print("power",...)
	test.savetrc("power",...)
end

local function cls()
	disp.stopgif()
	uiwin.remove(appid)
	sys.deregapp(appid1)
	appid,appid1,typ = nil
end

local gifoff,gprsoff,offreason,offreasonid

function getoffreason()
	return offreasonid
end

local function poweroff()
	if gifoff and gprsoff then
		sys.poweroff(offreason)
	end
end

local function gifcb()
	if typ=="on" then
		light.clslcdbl(1)
		cls()
		idle.opn(true)
	else
		gifoff = true
		poweroff()
	end
end

local function refresh()	
	if typ=="on" or typ=="off" then
		disp.playgif("/ldata/power"..typ..".gif",0,0,1)
		audioapp.play(typ=="on" and audioapp.PWRON or audioapp.PWROFF,"/ldata/power"..typ..".mp3",nil,4)
		sys.timer_start(gifcb,typ=="on" and 4000 or 3000)
		if typ=="off" then msc.vib() end
	else
		require"key"
		if not chg.isinit() or chg.getstate()==1 then
			disp.playgif("/ldata/powerchg.gif",0,0,0)
		elseif not chg.getcharger() then
			sys.poweroff("chg1")
		elseif chg.getstate()==2 then
			disp.stopgif()
			disp.clear()
			disp.putimage("/ldata/chgful.png")
			disp.update()
		end
	end
end

local repowerflg
function getrepowerflg()
	return repowerflg
end

local function repoweron()
	repowerflg = true
	rtos.repoweron()
end

local function chgonind()
	if typ=="chg" then
		disp.stopgif()
		dialog.opn("prompt","为了安全","请拔掉充电器","再开机",nil,nil,5000)
		--open("on")
		--sys.timer_start(repoweron,2500)
	end
	return true
end

local function keyind()
	if appid then chgonind() end
	return (appid==nil)
end

function losefocus()
	print('losefocus')
	disp.stopgif()
end

local function chgstaind(r)
	print("chgstaind",typ,r)
	if typ=="chg" then
		if r==1 then
			disp.playgif("/ldata/powerchg.gif",0,0,0)
		elseif r==2 then
			disp.stopgif()
			disp.clear()
			disp.putimage("/ldata/chgful.png")
			disp.update()
		end
	end
	return true
end

local function tpind()
end

local function chgind(s)
	print("chgind",typ,s)
	if typ=="chg" then
		if not s then sys.poweroff("chg2") end
	end
	return true
end

local app = {
	onUpdate = refresh,
	onTouch = tpind,
	MMI_LOSE_FOCUS_IND = losefocus,
	name="power",
}
local app1 = {
	KEY_LONG_IND = keyind,
	DEV_CHG_IND = chgind,
	DEV_CHG_STATUS_IND = chgstaind,
}
function open(t)
	print("power-open",t)
	typ = t	
	if appid then uiwin.remove(appid) end
	appid = uiwin.add('false',app)
	if not appid1 then appid1= sys.regapp(app1) end
	light.opnlcdbl(t~="chg" and 1 or 0)
	if t=="on" then
		nvm.set("powerofflg",0)
		nvm.set("flyflg",0)
	end
end

function offhandle(v,e,id)
	nvm.set("restartmute",false)
	wifi.wake("feed")
	offreason,offreasonid,gifoff,gprsoff = e,id
	nvm.set("powerofflg",1)
	sys.dispatch("SLEEP_OR_POWEROFF_REQ","NORMAL")
	btuartproto.snd(btuartproto.SLP)
	open("off")
end

function off(e,id)
	sys.dispatch("POWEROFF_REQ",e,id)
end

local function gprsoffcb(e,v)
	if v=="NORMAL" then
		gprsoff = true
		poweroff()
	end
	return true
end

function isonoff()
	return (typ=="on" or typ=="off")	
end

function isactive()
	return (appid and uiwin.iswinappactive(appid))
end

mmk.regnoretcb(isactive)

sys.regapp(offhandle,"POWEROFF_REQ")
sys.regapp(gprsoffcb,"SLEEP_OR_POWEROFF_CNF")
if _G.HWVER=="A14" and pins.get(pins.BB_SLP_STATUS) then
	if rtos.poweron_reason()==rtos.POWERON_CHARGER then rtos.repoweron() end
	idle.opn(true)
	nvm.set("powerofflg",0)
	nvm.set("flyflg",0)
	if rtos.keypad_state()==1 then rtos.keypad_init_end() pmd.ldoset(nvm.get("lcdblval"),pmd.LDO_SINK) end
else
	open(rtos.poweron_reason()==rtos.POWERON_CHARGER and "chg" or "on")
	rtos.keypad_init_end()
	pmd.ldoset(nvm.get("lcdblval"),pmd.LDO_SINK)
end
