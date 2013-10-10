local ffi = require("ffi")
ffi.cdef[[
struct timeval {
	uint64_t      tv_sec;
	uint64_t      tv_usec;
};
uint64_t time(uint64_t *t);
int gettimeofday(struct timeval *tv, struct timezone *tz);
]]
timeval = ffi.typeof("struct timeval");

local hitime = function()
	local tv = timeval();
	ffi.C.gettimeofday(tv,nil);
	return tonumber(tv.tv_sec) + tonumber(tv.tv_usec)/1e6;
end

return hitime;
