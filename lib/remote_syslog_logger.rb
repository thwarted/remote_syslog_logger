
require 'remote_syslog_logger/sender'
require 'logger'

module RemoteSyslogLogger
  VERSION = '1.0.3'

  def self.new(remote_hostname, remote_port, options = {})
    self.new_udp(remote_hostname, remote_port, options = {})
  end

  def self.new_udp(remote_hostname, remote_port, options = {})
    Logger.new(RemoteSyslogLogger::UdpSender.new(remote_hostname, remote_port, options))
  end

  def self.new_unix_dgram(path, options = {})
    Logger.new(RemoteSyslogLogger::UNIXDGRAMSender.new(path, options))
  end

  def self.new_unix_stream(path, options = {})
    Logger.new(RemoteSyslogLogger::UNIXStreamSender.new(path, options))
  end
end
