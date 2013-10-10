local ffi = require("ffi")
ffi.cdef[[
long int recvfrom(int sockfd, void *buf, size_t len, int flags, struct sockaddr *src_addr, int *addrlen);
int setsockopt(int sockfd, int level, int optname, const void *optval, int optlen);
]]

SOL_SOCKET = 1
SO_RCVBUF = 8

local function udpserver(srv,worker)
	return function ()
		box.fiber.detach()
		box.fiber.name("udpserver " .. srv.config.host .. ":" .. srv.config.port)
		local count = 0;
		local fd = tonumber(string.match(tostring(srv.sock),'(%d+)'));
		local bfs = ffi.new("int[1]", 4*1024*1024);
		ffi.C.setsockopt(fd, SOL_SOCKET, SO_RCVBUF, ffi.cast('int *',bfs),ffi.sizeof(bfs))
		local buf = ffi.new("char[4096]")
		while true do
			local count = 0
			while (true) do
				local n = ffi.C.recvfrom(fd,ffi.cast('char *',buf),ffi.sizeof(buf),0,nil,nil)
				if (n == -1) then break end
				count = count + 1
				local r,e = pcall(worker,ffi.string(buf,n))
				if (not r) then
					print("error in udp worker: ",e)
				end
			end
			box.fiber.sleep(0.0001)
		end
	end
end

local UdpServer = {
	stop = function (self)
		print("call stop")
		self.sock:close()
		box.fiber.cancel(self.f)
	end;
	start = function (self)
		if (self.f) then
			error("server already running")
		end
		local sock = box.socket.udp()
		sock:bind(self.config.host, self.config.port, 1);
		sock:listen()
		print("udp server bound to ",self.config.host,":",self.config.port)
		self.sock = sock;
		self.f = box.fiber.create(udpserver(self,self.worker))
		box.fiber.resume(self.f)
	end;
}

UdpServer.__index = UdpServer;

local function server(config,worker)
	if (config.port == nil) then
		error("udp server port required")
	end
	if (worker == nil) then
		error("worker required")
	end
	if (config.host == nil) then
		config.host = "0.0.0.0"
	end
	if (config.msgsize == nil) then
		config.msgsize = 10000
	end
	
	local srv = {
		config = config;
		worker = worker;
	};
	setmetatable(srv, UdpServer);
	return srv;
end

return {
	server = server
};
