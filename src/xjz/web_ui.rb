module Xjz
  class WebUI
    attr_reader :env, :template_dir

    def initialize(app)
      @app = app
      @template_dir = $config['template_dir'] || File.join($root, 'src/views')

      @history = {}
    end

    def call(env)
      if web_ui_request?(env)
        dup._call(env)
      else
        @app.call(env).tap do |code, headers, res|
          (@history[env['SERVER_NAME']] ||= []) << [env, code, headers, res]
        end
      end
    end

    def web_ui_request?(env)
      # TCPSocket is http direct connection
      # OpenSSL::SSL::SSLServer is proxy https connection
      env['puma.socket'].is_a?(TCPSocket) && env['REQUEST_URI'] =~ %r{^/}
    end

    def _call(env)
      body = fetch_template('index').render(Struct.new(:history).new(@history))

      [200, {}, [body]]
    end

    def fetch_template(name)
      Slim::Template.new(File.join(template_dir, "#{name}.slim"))
    end
  end
end
