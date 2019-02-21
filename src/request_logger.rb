class RequestLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    logs = [env['REQUEST_METHOD'], env['HTTP_HOST'], env['REQUEST_URI']]
    # data = env.select { |k, v| k =~ /^[A-Z\-_]+$/ }
    # data_log = data.sort.map { |kv| kv.join(': ') }.join("\n")
    # $logger.debug "======= Req ENV ======\n#{data_log}\n================="

    @app.call(env).tap do |code, _header, _body|
      logs << code
    end
  ensure
    $logger.info logs.join(' ')
  end
end
