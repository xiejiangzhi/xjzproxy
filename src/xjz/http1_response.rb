module Xjz
  class HTTP1Response
    attr_reader :res

    def initialize(req_method, env)
      @env = env
      @url = env['xjz.url']
      headers = RequestHelper.fetch_req_headers(@env)
      env['xjz.req_headers'] = headers
      body = @env['rack.input'].read
      opts = { headers: headers, timeout: $config['proxy_timeout'], follow_redirects: false }
      opts[:body] = body if body.present?

      Logger[:request].debug([req_method, @url, opts].inspect)
      @res = HTTParty.send(req_method, @url, opts)
    end

    def to_response
      headers = RequestHelper.process_res_headers(res.header.to_hash)
      Rack::Response.new([res.body], res.code, headers).finish
    end
  end
end

