require File.expand_path('../helper', __FILE__)

class TestRemoteSyslogLogger < Test::Unit::TestCase
  def setup
    @server_port = rand(50000) + 1024
    @socket = UDPSocket.new
    @socket.bind('127.0.0.1', @server_port)

    @ussocket = UNIXServer.new("unixtest."+rand(50000).to_s)

    s = Socket.new(:UNIX, :DGRAM, 0)
    s.bind(Addrinfo.unix("unixtest."+rand(50000).to_s))
    @udsocket = UNIXSocket.for_fd(s.fileno)
  end

  def teardown
    File.delete(@ussocket.path)
    File.delete(@udsocket.path)
  end
  
  def test_logger_unix_dgram
    logger = RemoteSyslogLogger.new_unix_dgram(@udsocket.path)
    logger.info "This is a test"
    
    message, addr = *@udsocket.recvfrom(1024)
    assert_match /This is a test/, message
  end

  def test_logger_multiline_unix_dgram
    logger = RemoteSyslogLogger.new_unix_dgram(@udsocket.path)
    logger.info "This is a test\nThis is the second line"

    message, addr = *@udsocket.recvfrom(1024)
    assert_match /This is a test/, message

    message, addr = *@udsocket.recvfrom(1024)
    assert_match /This is the second line/, message
  end

  def test_logger_unix_stream
    logger = RemoteSyslogLogger.new_unix_stream(@ussocket.path)
    logger.info "This is a test"

    s = @ussocket.accept
    message, addr = *s.recvfrom(1024)
    assert_match /This is a test/, message
  end

  def test_logger_multiline_unix_stream
    logger = RemoteSyslogLogger.new_unix_stream(@ussocket.path)
    testdata = "This is a test\nThis is the second line\nThird line"
    logger.info testdata

    s = @ussocket.accept
    # in packet based transports, the transport framing is used to
    # delimit messages.  With stream based transports, the messages
    # need record terminators, so expect multiple records delimited
    # by newlines here
    #
    # NOTE the test data is less than 1024 bytes, so the recvfrom
    # call will get multiple lines as a single string
    # so confirm they look like syslog formatted data
    message, addr = *s.recvfrom(1024)
    testlines = testdata.split(/\n/)
    message.split(/\n/).each do |line|
        testline = testlines.shift
        assert_match /^<\d+>.+#{testline}$/, line
    end
  end

  def test_logger_udp
    logger = RemoteSyslogLogger.new('127.0.0.1', @server_port)
    logger.info "This is a test"

    message, addr = *@socket.recvfrom(1024)
    assert_match /This is a test/, message
  end

  def test_logger_multiline_udp
    logger = RemoteSyslogLogger.new('127.0.0.1', @server_port)
    logger.info "This is a test\nThis is the second line"

    message, addr = *@socket.recvfrom(1024)
    assert_match /This is a test/, message

    message, addr = *@socket.recvfrom(1024)
    assert_match /This is the second line/, message
  end
end
