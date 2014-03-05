require 'socket'
require 'syslog_protocol'

module RemoteSyslogLogger
  class Sender
    def initialize(options = {})
      @whinyerrors     = options[:whinyerrors]
      
      @packet = SyslogProtocol::Packet.new

      local_hostname   = options[:local_hostname] || (Socket.gethostname rescue `hostname`.chomp)
      local_hostname   = 'localhost' if local_hostname.nil? || local_hostname.empty?
      @packet.hostname = local_hostname

      @packet.facility = options[:facility] || 'user'
      @packet.severity = options[:severity] || 'notice'
      @packet.tag      = options[:program]  || "#{File.basename($0)}[#{$$}]"
    end

    def _transmit(data)
      @socket.send(data, 0)
    end
    
    def transmit(message)
      message.split(/\r?\n/).each do |line|
        begin
          next if line =~ /^\s*$/
          packet = @packet.dup
          packet.content = line
          _transmit(packet.assemble)
        rescue
          $stderr.puts "#{self.class} error: #{$!.class}: #{$!}\nOriginal message: #{line}"
          raise if @whinyerrors
        end
      end
    end
    
    # Make this act a little bit like an `IO` object
    alias_method :write, :transmit
    
    def close
      @socket.close
    end
  end

  class UdpSender < Sender
    def initialize(remote_hostname, remote_port, options = {})
      @socket = UDPSocket.new
      @socket.connect(remote_hostname, remote_port)
      super(options)
    end
  end

  class UNIXDGRAMSender < Sender
    def initialize(path, options = {})
      s = Socket.new(:UNIX, :DGRAM, 0)
      s.connect(Addrinfo.unix(path))
      @socket = UNIXSocket.for_fd(s.fileno)
      super(options)
    end
  end

  class UNIXStreamSender < Sender
    def initialize(path, options = {})
      @socket = UNIXSocket.new(path)
      super(options)
    end

    def _transmit(data)
      # in packet based transports, the transport framing is used to
      # delimit messages.  With stream based transports, the messages
      # need record terminators so use a newline to terminate each
      # message.
      # This works with syslog-ng over stream based transports and
      # linux's /dev/log (which is SOCK_STREAM)
      @socket.send(data, 0)
      @socket.send("\n", 0)
    end
  end

end
