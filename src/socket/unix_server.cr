require "./unix_socket"

# A local interprocess communication server socket.
#
# Available on UNIX-like operating systems, and Windows 10 Build 17063 or above.
# Not all features are supported on Windows.
#
# NOTE: To use `UNIXServer`, you must explicitly import it with `require "socket"`
#
# Example usage:
# ```
# require "socket"
#
# def handle_client(client)
#   message = client.gets
#   client.puts message
# end
#
# server = UNIXServer.new("/tmp/myapp.sock")
# while client = server.accept?
#   spawn handle_client(client)
# end
# ```
class UNIXServer < UNIXSocket
  include Socket::Server

  # Creates a named UNIX socket, listening on a filesystem pathname.
  #
  # Always deletes any existing filesystem pathname first, in order to cleanup
  # any leftover socket file.
  #
  # The server is of stream type by default, but this can be changed for
  # another type. For example datagram messages:
  #
  # ```
  # UNIXServer.new("/tmp/dgram.sock", Socket::Type::DGRAM)
  # ```
  #
  # [Only the stream type is supported on Windows](https://devblogs.microsoft.com/commandline/af_unix-comes-to-windows/#unsupportedunavailable).
  def initialize(path : Path | String, type : Type = Type::STREAM, backlog : Int = 128)
    @path = path = path.to_s
    super(Family::UNIX, type)

    system_bind(UNIXAddress.new(path), path) do |error|
      close(delete: false)
      raise error
    end

    return if type == Type::DGRAM
    listen(backlog) do |error|
      close
      raise error
    end
  end

  # Creates a UNIXServer from an existing system file descriptor or socket
  # handle.
  #
  # This adopts *fd* into the IO system that will reconfigure it as per the
  # event loop runtime requirements.
  #
  # NOTE: On Windows, the handle must have been created with
  # `WSA_FLAG_OVERLAPPED`.
  def initialize(*, fd : Handle, type : Type = Type::STREAM, path : Path | String? = nil)
    @path = path = path.to_s
    super(fd: fd, type: type, path: path)
  end

  # Creates a new UNIX server and yields it to the block. Eventually closes the
  # server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(path : Path | String, type : Type = Type::STREAM, backlog = 128, &)
    server = new(path, type, backlog)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Accepts an incoming connection.
  #
  # Returns the client socket or `nil` if the server is closed after invoking
  # this method.
  def accept? : UNIXSocket?
    if rs = Crystal::EventLoop.current.accept(self)
      sock = UNIXSocket.new(handle: rs[0], type: type, path: @path, blocking: rs[1])
      sock.sync = sync?
      sock
    end
  end

  # Closes the socket, then deletes the filesystem pathname if it exists.
  def close(delete = true) : Nil
    super()
  ensure
    if delete && (path = @path)
      File.delete?(path)
      @path = nil
    end
  end
end
