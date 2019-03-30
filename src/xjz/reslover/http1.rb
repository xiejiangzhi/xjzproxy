module Xjz
  class Reslover::HTTP1
    attr_reader :res, :req, :proxy_client

    def initialize(req)
      @req = req
      @res = nil
      @proxy_client = ProxyClient.new(req.host, req.port, ssl: req.scheme == 'https', protocol: 'http1')
    end

    def perform
      Logger[:auto].info { "Perform by HTTP1" }
      res = proxy_client.send_req(req)
      HTTPHelper.write_res_to_conn(res, req.user_socket)
      return if res.conn_close?

      parser = HTTPParser.new
      close_conn = false
      user_socket = req.user_socket
      parser.on_finish do |env|
        HTTPHelper.write_conn_info_to_env!(env, user_socket)
        res = proxy_req(Request.new(env))
        close_conn = res.conn_close?
      end

      IOHelper.forward_streams(
        { user_socket => WriterIO.new(parser) },
        stop_wait_cb: proc { close_conn }
      )
    end

    private

    def proxy_req(req)
      proxy_client.send_req(req).tap do |res|
        HTTPHelper.write_res_to_conn(res, req.user_socket)
      end
    end
  end
end
