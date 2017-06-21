local f = assert(io.open("/loadlib.lua")); 
local s = f:read("*all");
print("befor write file:\r\n");
print(s);
print("\r\n");
f:close();

local f = assert(io.open("/loadlib.lua", "a+"));
f:write("append write file test.\r\n");
f:seek("set", 0);
s = f:read("*all");
print("after write file:\r\n");
print(s);
print("\r\n");
f:close();