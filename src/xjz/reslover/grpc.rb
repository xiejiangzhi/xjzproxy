module Xjz
  class Resolver::GRPC
    attr_reader :req

    def initialize(req)
      @req = req
    end

    def perform
      Logger[:auto].info { "Perform by GRPC" }
      sock = req.user_socket
      HTTPHelper.write_res_to_conn(Response.new({ 'Content-Length' => '0' }, [], 200), sock)

      HTTPParser.parse_request(sock) do |env|
        env['xjz.grpc'] = true
        RequestDispatcher.new.call(env)
      end
    end
  end
end
