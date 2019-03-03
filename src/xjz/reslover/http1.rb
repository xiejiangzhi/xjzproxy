module Xjz
  class Reslover::HTTP1
    attr_reader :res, :req

    def initialize(req)
      @req = req
      @res = nil
    end

    def response
      @response ||= ProxyClient.new.send_req(req)
    end

    def perform
      response.to_rack_response
    end
  end
end
