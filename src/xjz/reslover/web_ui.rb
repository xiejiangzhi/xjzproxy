module Xjz
  class Reslover::WebUI
    attr_reader :req, :template_dir

    def initialize(req)
      @req = req
      @template_dir = $config['template_dir'] || File.join($root, 'src/views')

      @history = {}
    end

    def perform
      body = fetch_template('index').render(Struct.new(:history).new(@history))

      [200, {}, [body]]
    end

    def web_ui_request?(env)
      # TCPSocket is http direct connection
      # OpenSSL::SSL::SSLServer is proxy https connection
      env['puma.socket'].is_a?(TCPSocket) && env['REQUEST_URI'] =~ %r{^/}
    end

    def fetch_template(name)
      Slim::Template.new(File.join(template_dir, "#{name}.slim"))
    end
  end
end
