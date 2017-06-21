--[[
模块名称：指示灯
模块功能：指示灯显示控制
模块最后修改时间：2017.02.16
]]

module(...,package.seeall)

--[[
1-5，优先级由低到高：
	IDLE:三灯长灭
	LOWPWR:低电量，红灯1秒闪烁1次，其余灯灭
	CHGING:充电中，红灯常亮，其余灯灭
	SHORTKEY:短按，绿灯闪一次
	LONGKEY:长按，蓝灯闪一次	
1-3，状态：
	INACTIVE:未激活
	PEND:等待被激活
	ACTIVE:激活
--]]
local IDLE,LOWPWR,CHGING,SHORTKEY,LONGKEY,PRIORITYCNT = 1,2,3,4,5,5
local INACTIVE,PEND,ACTIVE = 1,2,3
local tcause = {}
--按照红绿蓝排序，每个灯占用2个位置，每个位置可以设置是否生效，是否点亮，以及对应的时间(默认1秒钟)
local tledpin = 
{
	[pmd.KP_LEDR]=0,
	[pmd.KP_LEDG]=0,
	[pmd.KP_LEDB]=0,
}
local tled,ledcnt,ledpos,ledidx = {},3,2,1

local function isvalid()
	local i
	for i=1,ledpos*ledcnt do
		if tled[i].valid then return true end
	end
end

local function init()
	local i
	
	tcause[IDLE] = ACTIVE
	for i=IDLE+1,PRIORITYCNT do
		tcause[i] = INACTIVE
	end
	
	for i=1,ledpos*ledcnt do
		tled[i] = {}
		tled[i].pin = (i > ledpos*(ledcnt-1)) and pmd.KP_LEDB or((i > ledpos*(ledcnt-2)) and pmd.KP_LEDG or pmd.KP_LEDR)
		tled[i].valid = true
		tled[i].on = false
		tled[i].prd = 1000
	end
end

local function starttimer(idx,cb,prd)
	if tcause[idx] == ACTIVE and not sys.timer_is_active(cb) then
		sys.timer_start(cb,prd)
	end
end

local function proc()
	if not isvalid() then return end
	local i = ledidx
	while true do
		if tled[i].valid then			
			--print("light.proc",i,tled[i].on,tled[i].prd)
			local k,v
			for k,v in pairs(tledpin) do
				if k ~= tled[i].pin and v ~= 0 then
					pmd.ldoset(0,k)
					tledpin[k] = 0
					--print("light.ldo",k,0)
				end
			end
			local flag,pin = (tled[i].on and 1 or 0),tled[i].pin
			if tledpin[pin] ~= flag then
				pmd.ldoset(flag,pin)
				tledpin[pin] = flag
				--print("light.ldo",pin,flag)
			end
			starttimer(SHORTKEY,shortkeyend,500)
			starttimer(LONGKEY,longkeyend,500)
			starttimer(LOWPWR,lowpwrend,500)
			sys.timer_start(proc,tled[i].prd)
			ledidx = (i+1 > ledcnt*ledpos) and 1 or (i+1)
			if tcause[IDLE] == ACTIVE then
				tled[i].valid = false
			end
			return
		else
			i = (i+1 > ledcnt*ledpos) and 1 or (i+1)
		end
	end
end

local function updflicker(head,tail,prd)
	--print("light.updflicker",head,tail,prd)
	local j
	--[[for j=1,ledpos*ledcnt do
		print("tled["..j.."].valid",tled[j].valid)
		print("tled["..j.."].on",tled[j].on)
		print("tled["..j.."].prd",tled[j].prd)
	end]]
	for j=1,ledpos*ledcnt do
		if j>=head and j<=tail then
			tled[j].valid = true
			tled[j].on = (j%ledpos == 1)
			tled[j].prd = prd
		else
			tled[j].valid = false
		end			
	end
	--[[for j=1,ledpos*ledcnt do
		print("tled["..j.."].valid",tled[j].valid)
		print("tled["..j.."].on",tled[j].on)
		print("tled["..j.."].prd",tled[j].prd)
	end]]
end

local function updled()
	local i,idx
	for i=IDLE,PRIORITYCNT do
		--print("light.updled",i,tcause[i])
		if tcause[i] == ACTIVE then idx=i break end
	end
	--print("light.updled",idx)
	if idx == LONGKEY then
		updflicker(5,5,500)
	elseif idx == SHORTKEY then
		updflicker(3,3,500)
	elseif idx == CHGING then
		updflicker(1,1,1000)
	elseif idx == LOWPWR then
		updflicker(1,1,500)
	elseif idx == IDLE then
		updflicker(2,2,1000)
	end
	if not sys.timer_is_active(proc) then proc() end
end

local function updcause(idx,val)
	local i,pend,upd
	--[[print("light.updcause",idx,val)
	for i=1,PRIORITYCNT do
		print("tcause["..i.."]="..tcause[i])
	end]]
	if val then
		for i=idx+1,PRIORITYCNT do
			if tcause[i] == PEND or tcause[i] == ACTIVE then
				tcause[idx] = PEND
				pend = true
				break
			end
		end
		if not pend and tcause[idx] ~= ACTIVE then
			tcause[idx] = ACTIVE
			for i=1,idx-1 do
				if tcause[i] == ACTIVE then tcause[i] = PEND end
			end
			upd = true
		end
	else
		if tcause[idx] == ACTIVE then
			for i=idx-1,1,-1 do
				if tcause[i] == PEND then tcause[i] = ACTIVE break end
			end
			upd = true
		end
		tcause[idx] = INACTIVE
	end
	--[[print("light.updcause",pend,upd)
	for i=1,PRIORITYCNT do
		print("tcause["..i.."]="..tcause[i])
	end]]
	if upd then updled() end
end

local function chgind(evt,val)
	--print("light.chgind",evt,val)
	updcause((evt == "CHG_STATUS") and CHGING or LOWPWR,val)
	return true
end

local function keyind()
	updcause(SHORTKEY,true)
	return true
end

local function keylngpresind(k,r)
	if r == "KEY" then
		updcause(LONGKEY,true)
	end
	return true
end

function shortkeyend()
	updcause(SHORTKEY,false)
end

function longkeyend()
	updcause(LONGKEY,false)
end

function lowpwrend()
	updcause(LOWPWR,false)
end

local procer =
{
	DEV_CHG_IND = chgind,
	MMI_KEYPAD_IND = keyind,
	MMI_KEYPAD_LONGPRESS_IND = keylngpresind,
}
sys.regapp(procer)
init()
proc()
