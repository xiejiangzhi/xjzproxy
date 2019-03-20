module Xjz
  class Reslover::Forward
    attr_reader :req

    def intialize(req)
      @req = req
    end

    def perform
      server_socket = TCPSocket.new(req.host, req.port)
      user_socket = req.user_socket
      IOHelper.forward_streams(
        server_socket => user_socket,
        user_socket => server_socket
      )
    ensure
      user_socket.close
      server_socket.close
    end
  end
end
