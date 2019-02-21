class CommonEnv
  def initialize(app)
    @app = app
  end

  def call(env)
    req = (env['xjz.request'] = Rack::Request.new(env))
    env['xjz.url'] = req.url
    @app.call(env)
  end
end
