class HTTPClient
  include HTTParty

  persistent_connection_adapter(
    pool_size: $config['max_threads']
  )
end
