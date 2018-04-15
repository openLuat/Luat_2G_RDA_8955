require"update"
module(...,package.seeall)

local retry = 0

local function upevt(ind,para)
	--服务器有新版本
	if ind == "NEW_VER_IND" then		
		--允许下载新版本
		para(true)
	--下载结束
	elseif ind == "UP_END_IND" then
		if para then
			sys.restart("updapp suc")
		else
			if retry<3 then
				link.shut()
				sys.timer_start(update.request,5000)
				retry = retry+1
			else
				sys.restart("updapp fail")
			end
		end
	end
end

local procer =
{
	UP_EVT = upevt,
}

sys.regapp(procer)
sys.timer_start(sys.restart,300000,"updapp timeout")
