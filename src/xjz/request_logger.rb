module Xjz
  class RequestLogger
    def initialize(app)
      @app = app
    end

    def call(env)
      logs = [env['REQUEST_METHOD'], env['HTTP_HOST'], env['REQUEST_URI']]
      if env['REQUEST_PATH'] != '/favicon.ico' && env['REQUEST_METHOD'] != 'CONNECT'
        data = env.select { |k, v| k =~ /^[A-Z\-_]+$/ }
        data_log = data.sort.map { |kv| kv.join(': ') }.join("\n")
        Logger[:request].debug "======= Req ENV ======\n#{data_log}\n================="
      end

      @app.call(env).tap do |code, _header, _body|
        logs << code
      end
    ensure
      Logger[:request].info logs.join(' ')
    end
  end
end
