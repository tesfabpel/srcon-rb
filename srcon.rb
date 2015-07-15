
require 'socket'
require 'readline'

module Rcon
	RconPacket = Struct.new(:size, :id, :type, :body)

	module PacketType
		SERVERDATA_AUTH = 3
		SERVERDATA_AUTH_RESPONSE = 2
		SERVERDATA_EXECCOMMAND = 2
		SERVERDATA_RESPONSE_VALUE = 0
	end

	def self.send_to(packet, sock)
		szb = [packet[:size]].pack 'l<'
		idb = [packet[:id]].pack 'l<'
		typeb = [packet[:type]].pack 'l<'
		bodyb = [packet[:body]].pack 'Z*'
		msg = szb+idb+typeb+bodyb+"\0"

		sock.sendmsg(msg)
	end

	def self.recv_from(sock)
		msgary = sock.recvmsg()
		msg = msgary[0]
		ary = msg.unpack('l<l<l<Z*')

		RconPacket.new(ary[0],ary[1],ary[2],ary[3])
	end

	def self.auth(sock)
		pass = Readline.readline('Password> ')
		if pass.nil? #EOF
			puts
			return false
		end

		p = Rcon::RconPacket.new(10+pass.bytesize, 0, Rcon::PacketType::SERVERDATA_AUTH, pass)
		Rcon::send_to(p, sock)
		pr = Rcon.recv_from(sock)
		if pr[:id] == -1
			return false
		end

		true
	end

	def self.looper(sock)
		loop do
			line = Readline.readline('rcon> ', true)
			if line.nil? #EOF
				puts
				break
			end

			p = Rcon::RconPacket.new(10+line.bytesize, 0, Rcon::PacketType::SERVERDATA_EXECCOMMAND, line)
			Rcon::send_to(p, sock)
			pr = Rcon.recv_from(sock)
			puts pr[:body]
		end
	end
end

if ARGV.length != 2
	exit false
end

host = ARGV[0]
port = ARGV[1].to_i

$sock = TCPSocket.new host, port

begin
	unless Rcon.auth($sock)
		puts "AUTH ERROR"
		exit false
	end

	Rcon.looper($sock)
rescue
end

$sock.close
