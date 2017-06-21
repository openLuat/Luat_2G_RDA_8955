
module(...,package.seeall)

EVT_CTRL = 0
EVT_KEY = 0x10
EVT_GPIO = 0x11

local evts = {}

local function defcb()
end

function add(vid,vcb)
	local t = {id = vid,cb = vcb}
	table.insert(evts,t)
	setmetatable(t, {__index = event})
	return t
end

function dispatch(d)
	local id = string.byte(d,1)

	for i,evt in ipairs(evts) do
		if evt.id == id then
			evt.cb(string.sub(d,2,-1))
		end
	end
end

function send(self,d)
	daemon.emit_event(self.id,d)
end
