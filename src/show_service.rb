class ShowService
  attr_reader :server, :ps

  def initialize(port, proxy_service)
    @server = WEBrick::HTTPServer.new Port: port
    @ps = proxy_service
    @server.mount_proc('/', &method(:render_index_page))
  end

  def start
    server.start
  end

  def render_index_page(req, res)
    res.body = Slim::Template.new('./index.slim').render(
      Struct.new(:history, :proxy).new(ps.history, ps.proxy)
    )
  end
end
