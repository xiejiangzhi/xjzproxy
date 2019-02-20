class RequestLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    data = env.select { |k, v| k =~ /^HTTP_/ }
    $logger.debug [env['REQUEST_URI'], env['HTTP_HOST']].join(' ')
    $logger.debug data.sort.map { |kv| kv.join(': ') }.join("\n")
    @app.call(env)
  end
end
