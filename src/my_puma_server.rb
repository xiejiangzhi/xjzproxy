require 'puma/server'

class MyPumaServer < Puma::Server
  def normalize_env(env, client)
    env[REQUEST_PATH] ||= '' if env[REQUEST_METHOD] == 'CONNECT'
    super
  end
end
