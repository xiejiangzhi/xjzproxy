module Xjz
  class Resolver::GRPC
    attr_reader :req, :api_project

    def initialize(req, ap = nil)
      @api_project = ap
      @req = req
    end

    def perform
      Logger[:auto].info { "Perform by GRPC - #{api_project ? 'with AP' : ''}" }
      sock = req.user_socket
      HTTPHelper.write_res_to_conn(Response.new({ 'Content-Length' => '0' }, [], 200), sock)

      HTTPParser.parse_request(sock) do |env|
        env['xjz.grpc'] = true
        RequestDispatcher.new.call(env)
      end
    end
  end
end
