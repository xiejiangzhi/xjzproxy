class RequestLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    data = env.select { |k, v| k =~ /^HTTP_/ }
    $logger.debug '=' * 10 + " #{env['HTTP_HOST']} " + '=' * 10
    $logger.debug data.sort.map { |kv| kv.join(': ') }.join("\n")
    @app.call(env)
  end
end
