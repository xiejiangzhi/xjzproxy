class RequestProxy
  attr_reader :env

  def initialize(env)
    @env = env
  end

  def process
    [200, {}, ['hello proxy']]
  end
end
