require 'socket'
require 'readline'
require 'optparse'

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

def main
	config = {}
	op = OptionParser.new do |opts|
		opts.banner = "Usage: ruby srcon.rb host port [-p -|password] [-- command]"

		opts.separator ''

		opts.on('-p [password]', 'The password') do |pass|
			if pass.nil?
				STDERR.puts 'ERROR: You need to specify a password if -p is present.'
				opts.terminate
				exit
			end

			pass = nil if pass == '-'

			config[:password] = pass
		end
	end

	if ARGV.length < 2
		STDERR.puts "ERROR! Missing required arguments."
		STDERR.puts op.help
		exit false
	end

	host = ARGV.shift
	port = ARGV.shift.to_i

	op.parse

	# Parse the -- argument
	cmdi = ARGV.index '--'
	unless cmdi.nil?
		cmd_ary = ARGV[cmdi+1 .. -1]

		if cmd_ary.nil?
			STDERR.puts 'ERROR: Command is empty.'
			exit
		end
		cmd = cmd_ary.join(' ')
		config[:command] = cmd
	end

	$sock = TCPSocket.new host, port

	begin
		unless Rcon.auth($sock)
			STDERR.puts "AUTH ERROR"
			exit false
		end

		Rcon.looper($sock)
	rescue
	end

	$sock.close

end

if __FILE__ == $0
	main
end
