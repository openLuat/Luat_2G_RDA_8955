module(...,package.seeall)

local ssub,slen,sgmatch = string.sub,string.len,string.gmatch

local appid,appid1
local iconpos =
{
	[1] =
	{
		SIG = {l=6,t=6,r=45,b=35},
		SIG1 = {l=8,t=26,r=11,b=33},
		SIG2 = {l=19,t=20,r=21,b=33},
		SIG3 = {l=30,t=14,r=32,b=33},
		SIG4 = {l=40,t=8,r=43,b=33},
		BATBORDER = {l=181,t=6,r=234,b=35},
		BATCOL = {l=186,t=11},
		TIME = {l=0,t=48,r=185,b=86},
		TIMEW = {39,11,35,33,39,37,38,39,38,39,14},
		TIMEH = {37,37,37,37,37,37,37,37,37,37,29},
		DATE = {l=0,t=92,r=185,b=124},
		DATEITV = 0,
		DATEW = {22,8,20,19,22,21,21,21,21,22,23,25,49,49},
		DATEH = {21,21,21,21,21,21,21,21,21,21,26,25,27,27},
	},
	[2] =
	{
		SIG = {l=6,t=6,r=45,b=35},
		SIG1 = {l=8,t=26,r=11,b=33},
		SIG2 = {l=19,t=20,r=21,b=33},
		SIG3 = {l=30,t=14,r=32,b=33},
		SIG4 = {l=40,t=8,r=43,b=33},
		BATBORDER = {l=181,t=6,r=234,b=35},
		BATCOL = {l=186,t=11},
		TIME = {l=0,t=48,r=185,b=86},
		TIMEW = {39,11,35,33,39,37,38,39,38,39,14},
		TIMEH = {37,37,37,37,37,37,37,37,37,37,29},
		DATE = {l=0,t=92,r=185,b=124},
		DATEITV = 0,
		DATEW = {22,8,20,19,22,21,21,21,21,22,23,25,49,49},
		DATEH = {21,21,21,21,21,21,21,21,21,21,26,25,27,27},
	}
}

local function isactive()
	return uiwin.iswinappactive(appid) and light.getlcdbl()
end

local function update(s)
	if s and isactive() then  disp.update() end
end

local function dispbg(tag,flag)
	local id = nvm.get("theme")
	local rgn,x,y,l,t,r,b = iconpos[id][tag],0,0
	if tag and rgn then
		x,y,l,t,r,b = rgn.l,rgn.t,rgn.l,rgn.t,rgn.r,rgn.b
	end
	if flag then
		disp.layersetpicture(flag,"/ldata/idle"..id.."bg.bmp",x,y,-1,l,t,r,b)
	else	
		disp.putimage("/ldata/idle"..id.."bg.bmp",x,y,-1,l,t,r,b)
	end
end

local function updatebg(s,tag)
	if s and isactive() then dispbg(tag) end
end

local function dispsig(bg,flag)
	if not isactive() and  bg then return end
	local id,cnt,i = nvm.get("theme"),msc.getsiglev()
	updatebg(true,"SIG")
	if flag then 
		disp.layersetpicture(flag,"/ldata/idle"..((not msc.getsiminit() or msc.getsimrdy()) and "sig" or "simerr")..".png",iconpos[id]["SIG"].l,iconpos[id]["SIG"].t)			
	else
		disp.putimage("/ldata/idle"..((not msc.getsiminit() or msc.getsimrdy()) and "sig" or "simerr")..".png",iconpos[id]["SIG"].l,iconpos[id]["SIG"].t)
	end
	for i=1,cnt do
		if flag then
			disp.layersetdrawrect(flag,iconpos[id]["SIG"..i].l,iconpos[id]["SIG"..i].t,iconpos[id]["SIG"..i].r,iconpos[id]["SIG"..i].b,0xFFFFFF)
		else
			disp.drawrect(iconpos[id]["SIG"..i].l,iconpos[id]["SIG"..i].t,iconpos[id]["SIG"..i].r,iconpos[id]["SIG"..i].b,0xFFFFFF)
		end	
	end
	update(bg)	
end

local batcolcnt,batanimidx = 42,0

local function chginganim()
	batanimidx = (batanimidx+7 > batcolcnt) and 0 or (batanimidx+7)
	dispbat(true)
end

local function startchginganim()
	if not sys.timer_is_active(chginganim) then
		sys.timer_loop_start(chginganim,500)
		batanimidx = 0
	end
end

local function stopchginganim()
	sys.timer_stop(chginganim)
end

function dispbat(bg,flag)
	if not isactive() and bg then stopchginganim() return end	
	updatebg(bg,"BATBORDER")
	local id,p = nvm.get("theme")
	
	p = iconpos[id]["BATBORDER"]
	if bg then
		if flag then
			disp.layersetpicture(flag,"/ldata/idlebatborder.png",p.l,p.t)
		else
			disp.putimage("/ldata/idlebatborder.png",p.l,p.t)
		end
	end
	
	local cnt = batcolcnt/2	
	if chg.getstate()==1 then
		startchginganim()
		cnt = batanimidx
	else
		stopchginganim()
		cnt = chg.getlev()*batcolcnt/100
	end
	p = iconpos[id]["BATCOL"]
	if cnt>1 then
		if flag then
			disp.layersetdrawrect(flag,p.l,p.t,p.l+cnt-1,p.t+19,(chg.islow() and 0xE51A23 or 0x4CFF00))
		else
			disp.drawrect(p.l,p.t,p.l+cnt-1,p.t+19,(chg.islow() and 0xE51A23 or 0x4CFF00))
		end
	end

	update(bg)
end

local function getdateidx(str,i)
	local idx = ((tonumber(ssub(str,i,i)) or 0)+1)
	if i==3 then idx = 11 end
	if i==6 then idx = 12 end
	if i==7 then idx = (ssub(str,i,i)=="a" and 13 or 14) end
	return idx
end

local function getdatetag(str,i)
	local tag = ssub(str,i,i)
	if i==3 then tag = "mon" end
	if i==6 then tag = "day" end
	if i==7 then tag = (ssub(str,i,i)=="a" and "am" or "pm") end
	return tag
end

local function disptime(bg,flag)
	if not isactive() and bg then return end	
	updatebg(bg,"TIME")
	local clk = misc.getclockstr()
	local id,str,width = nvm.get("theme"),string.format("%02d",tonumber(ssub(clk,7,8)=="12" and "12" or (ssub(clk,7,8)%12)))
								.. ":" .. ssub(clk,9,10),0
	local itv,tag,i = iconpos[id]["TIMEITV"] or 0
	for i=1,5 do
		width = width+iconpos[id]["TIMEW"][(i==3 and 11 or (tonumber(ssub(str,i,i))+1))]+itv
	end
	width = width-itv
	local x,y,idx = (iconpos[id]["TIME"].r-iconpos[id]["TIME"].l+1-width)/2
	for i=1,5 do
		idx = (i==3 and 11 or (tonumber(ssub(str,i,i))+1))
		y = iconpos[id]["TIME"].t+(iconpos[id]["TIME"].b-iconpos[id]["TIME"].t+1-iconpos[id]["TIMEH"][idx])/2
		tag = (i==3 and "colon" or ssub(str,i,i))
		if flag then
			print('idle-time',tag)
			disp.layersetpicture(flag,"/ldata/idlet"..tag..".png",x,y)
		else
			disp.putimage("/ldata/idlet"..tag..".png",x,y)
		end
		x = x+iconpos[id]["TIMEW"][idx]+itv
	end	
	
	updatebg(bg,"DATE")
	str = ssub(clk,3,4).."m"..ssub(clk,5,6).."d"..(tonumber(ssub(clk,7,8))<12 and "a" or "p")
	itv,width = iconpos[id]["DATEITV"] or 0,0
	for i=1,7 do
		width = width+iconpos[id]["DATEW"][getdateidx(str,i)]+itv
	end
	width = width-itv
	local x,y = (iconpos[id]["DATE"].r-iconpos[id]["DATE"].l+1-width)/2
	for i=1,7 do
		y = iconpos[id]["DATE"].t+(iconpos[id]["DATE"].b-iconpos[id]["DATE"].t+1-iconpos[id]["DATEH"][getdateidx(str,i)])/2
		if flag then
			disp.layersetpicture(flag,"/ldata/idled"..getdatetag(str,i)..".png",x,y)
		else
			disp.putimage("/ldata/idled"..getdatetag(str,i)..".png",x,y)
		end
		x = x+iconpos[id]["DATEW"][getdateidx(str,i)]+itv
	end
	
	update(bg)
end

local function refresh()
	print('idle-refresh')
	--disp.clear()
	dispbg()
	dispsig(nil)
	dispbat(nil)
	disptime()
end

local function sigind()
	dispsig(true)
end

local function batind()
	dispbat(true)
end

local function chgstaind(data)
	dispbat(true)
	return true
end

local function clkind()
	if isactive() then disptime(true) end
	return true
end

local clicknum,darkcnt=0,0
local function rstclick()
	clicknum = 0
end

local function tpind(cmd,x,y)
	if  cmd=="MOVE"  then
	    if true == uiapp.ishaveapp() then
		  uiapp.draw(uiapp.totalapp, 1)
		else
		  mainmenu.draw(mainmenu.totalcnt,1)
		end
		mainmenu.draw(1,2)
		award.draw(3)
		qrcod.draw(4)
		uiwin.hoverstart(0,1,-1,40,60,0)
	elseif cmd=="SINGLE" and nvm.get("verflg")=="DEBUG" and nvm.get("darkflg") then
		if clicknum==2 then
			rstclick()
			if darkcnt>=10 then 
				nvm.set("darkflg",false)
				return
			end
			darkcnt = darkcnt+1
			darkcode.opn()
			return
		end
		clicknum=clicknum+1
		sys.timer_start(rstclick,700)
	end
end

function draw()
	refresh(true)
end

function hover_show(flag)
	dispbg(false,flag)
	dispsig(nil,flag)
	dispbat(nil,flag)
	disptime(false,flag)
end
function hoverend(x)	
	print('idle-hoverend',x)
	if x == 1 then
	    if true == uiapp.ishaveapp() then
		  uiapp.opn(uiapp.totalapp,true)
		else
		  mainmenu.opn(mainmenu.totalcnt)
		end
	elseif x==2 then
		mainmenu.opn()
	elseif x==3 then
		award.opn()
	elseif x==4 then
		qrcod.opn()
	end
end
local app = {
	onUpdate = refresh,
	onTouch = tpind,
	silp_end=hoverend,
	name="idle",
}
local app1 = {
	SIG_LEV_IND = sigind,
	BAT_LEV_IND = batind,
	DEV_CHG_STATUS_IND = chgstaind,
	CLOCK_IND = clkind,
}

local function loadkey()
	require"key"
end

function opn(typ)
	--require"key"
	sys.timer_start(loadkey,2000)
	temp='false'
	if typ then temp=false end
	audio.setmicrophonegain(7)
	nvm.set("restartmute",true)
	print("idle poweron",rtos.keypad_state())
	if rtos.keypad_state()==1 then
		light.opnlcdbl()
	end
	appid = uiwin.add(temp,app)
	appid1 = sys.regapp(app1)
	sys.dispatch("IDLE_OPN_IND")
	--sys.timer_start(sys.dispatch,20000,"SIL_POWEROFF_REQ")
end

function isact()
	return (appid and uiwin.iswinappactive(appid))
end

function isopn()
	return appid
end

mmk.regnoretcb(isact)
