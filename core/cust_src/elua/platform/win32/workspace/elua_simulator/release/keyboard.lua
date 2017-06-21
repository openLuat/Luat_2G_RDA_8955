
require"pack"
require"bit"
module(...,package.seeall)

local MAX_ROWS = 8
local MAX_COLS = 8

local evt_key
local dlg = iup.dialog
{
	iup.matrix
	{
		widthdef=30,
		scrollbar = "NO",
		id = "matrix"
	}
	;title = "keyboard"
}

local function bit2table(val,bits)
	local t = {}
	local v1 = 1

	for i=1,bits do
		if bit.band(val,v1) == v1 then
			table.insert(t,i)
		end
		v1 = v1*2
	end
	return	t
end

function matrix:click_cb(l,c,status)
	if l == 0 or c == 0 then return end
	local keyl,keyc = matrix:getcell(l,0),matrix:getcell(0,c)
	keyl,keyc = tonumber(string.match(keyl,"(%d+)")),tonumber(string.match(keyc,"(%d+)"))
	evt_key:send(string.pack("bbbb",0,1,keyc-1,keyl-1))
end

function matrix:release_cb(l,c,status)
	if l == 0 or c == 0 then return end
	local keyl,keyc = matrix:getcell(l,0),matrix:getcell(0,c)
	keyl,keyc = tonumber(string.match(keyl,"(%d+)")),tonumber(string.match(keyc,"(%d+)"))
	evt_key:send(string.pack("bbbb",0,0,keyc-1,keyl-1))
end

function open(r,c)
	matrix.numlin = #r
	matrix.numcol = #c
	matrix.numlin_visible = #r
	matrix.numcol_visible = #c

	for i=1,#r do
		matrix:setcell(i,0,"ROW"..r[i])
	end

	for i=1,#c do
		matrix:setcell(0,i,"COL"..c[i])
	end

	matrix.resize = "YES"

	dlg:show()
end

function proc_evt_key(d)
	local _,key_type,row_mask,col_mask = string.unpack(d,"III")
	local row,col = bit2table(row_mask,MAX_ROWS),bit2table(col_mask,MAX_COLS)

	open(row,col)
end

function close()
	dlg:hide()
end

evt_key = event.add(event.EVT_KEY,proc_evt_key)
