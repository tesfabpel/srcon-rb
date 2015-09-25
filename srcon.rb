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

	def self.get_sock
		host = $config[:host]
		port = $config[:port]

		TCPSocket.new host, port
	end

	def self.send_to(packet, sock)
		szb = [packet[:size]].pack 'l<'
		idb = [packet[:id]].pack 'l<'
		type_b = [packet[:type]].pack 'l<'
		body_b = [packet[:body]].pack 'Z*'
		msg = szb + idb + type_b + body_b + "\0"

		sock.sendmsg(msg)
	end

	def self.recv_from(sock)
		msg_ary = sock.recvmsg
		msg = msg_ary[0]
		ary = msg.unpack('l<l<l<Z*')

		RconPacket.new(ary[0],ary[1],ary[2],ary[3])
	end

	def self.send_recv(sock, msg, type = Rcon::PacketType::SERVERDATA_EXECCOMMAND)
		p = Rcon::RconPacket.new(10+msg.bytesize, 0, type, msg)
		Rcon::send_to(p, sock)
		pr = Rcon::recv_from(sock)
		pr
	end

	def self.parse_options
		config = {
			password_tmp: nil,
			password_verified: false,
		}

		op = OptionParser.new do |opts|
			opts.banner = "Usage: ruby srcon.rb host port [-p -|password] [-- command]"

			opts.separator ''

			opts.on('-p PASSWORD', 'The password') do |pass|
				if pass.nil?
					STDERR.puts 'ERROR: You need to specify a password if -p is present.'
					opts.terminate
					exit
				end

				pass = :stdin if pass == '-'

				config[:password] = pass
			end
		end

		if ARGV.length < 2
			STDERR.puts "ERROR! Missing required arguments."
			STDERR.puts op.help
			exit false
		end

		config[:host] = ARGV.shift
		config[:port] = ARGV.shift.to_i

		op.parse ARGV

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

		config
	end

	def self.ask_pass

		return if $config[:password_verified]

		pass = $config[:password]

		if pass.nil?
			# Ask using readline
			pass = Readline.readline('Password> ')

			if pass.nil? #EOF
				puts
				return false
			end
		elsif pass == :stdin
			# Read directly from stdin
			pass = gets.chomp
		end

		$config[:password_tmp] = pass
		$config[:password_verified] ||= false
	end

	def self.auth(sock)
		pass = $config[:password_tmp] || $config[:password]

		pr = Rcon::send_recv(sock, pass, Rcon::PacketType::SERVERDATA_AUTH)
		if pr[:id] == -1
			$config[:password_verified] = false
			return false
		end

		$config[:password] = pass
		$config[:password_tmp] = nil
		$config[:password_verified] = true

		true
	end

	def self.single_command

		begin
			Rcon::ask_pass

			line = Readline.readline('rcon> ', true)
			if line.nil? #EOF
				puts
				raise new EOFError
			end

			sock = Rcon::get_sock()

			begin
				#puts "OPEN"

				unless Rcon::auth(sock)
					raise "Authentication Error"
				end

				pr = Rcon::send_recv(sock, line)
				puts pr[:body]
			rescue
				p $!
			end

			#puts "CLOSE"
			sock.close

		rescue EOFError => e
			raise e

		end

	end

	def self.looper
		loop do
			Rcon::single_command
		end
	end
end

def main
	$config = Rcon::parse_options

	begin
		cmd = $config[:command]

		# Do we already have a command?
		if cmd.nil?
			Rcon::looper
		else
			Rcon::single_command
		end
	rescue EOFError
		# ignored
	rescue
		p $!
		exit false
	end

	exit true
end

if __FILE__ == $0
	main
end
