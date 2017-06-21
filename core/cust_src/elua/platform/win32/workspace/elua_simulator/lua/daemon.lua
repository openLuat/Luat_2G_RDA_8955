
require"socket"
require"event"
module(...,package.seeall)

local ctx = {
	--state = "idle",
	sockid = nil,
}

function poll()
	if ctx.sockid then
		local s = ctx.sockid:receive()

		if s and string.len(s) > 2 then
			local len = string.byte(s,1)*256 + string.byte(s,2)
			if len == string.len(s) then
				event.dispatch(string.sub(s,3,-1))
			end
		end
	end
end

function close()
	ctx.sockid:close()
	ctx = {}
	removetask(poll)
end

function open()
	ctx.sockid = socket.udp()
	ctx.sockid:setsockname("127.0.0.1",62888)
	ctx.sockid:settimeout(0)
	addtask(poll)
end

function emit_event(id,d)
	if not ctx.sockid then return end

	local len = string.len(d)+3
	local outd = string.char(len/256,len%256,id) .. d
	ctx.sockid:sendto(outd,"127.0.0.1",62887)
end
