require 'json'
require 'csv'

module Xjz
  class ApiProject::ResponseRenderer
    CONTENT_TYPES = {
      json: 'application/json',
      xml: 'application/xml',
      csv: 'text/csv',
      grpc: /\Aapplication\/grpc(\-web)?(\+(proto|json))?\Z/,
      text: /\Atext\/\w+/,
    }
    VALID_TYPES = CONTENT_TYPES.values

    attr_reader :api_project

    def initialize(ap)
      @api_project = ap
    end

    def render(req, res_desc)
      if res_desc.blank?
        Logger[:auto].warn { "Response description is empty" }
        return Response.new({}, 'Not found response' , 400)
      end

      headers = render_headers(res_desc['headers'])
      ct = HTTPHelper.get_header(headers, 'content-type')
      unless ct
        ct = get_accept_type(req, res_desc['data'])
        HTTPHelper.set_header(headers, 'content-type', ct)
      end

      if CONTENT_TYPES[:grpc] === ct && api_project.grpc&.find_rpc(req.path).blank?
        Logger[:auto].error { "Not found rpc service for #{req.path}" }
        return Response.new({}, "Not found rpc service for #{req.path}", 400)
      end

      body = render_body(res_desc['data'])
      body = format_body(req, body, ct)

      Response.new(headers, body, res_desc['http_code'] || 200)
    end

    def render_headers(conf)
      (conf || []).map do |k, v|
        [k.to_s.downcase.tr('_', '-'), v]
      end
    end

    def render_body(conf, depth = 100)
      return conf if depth < 0

      case conf
      when ApiProject::DataType
        conf.generate
      when Hash
        conf.each_with_object({}) do |kv, r|
          k, v = kv
          next if k[0] == '.'
          r[k] = render_body(v, depth - 1)
        end
      when Array
        conf.map { |v| render_body(v, depth - 1) }
      else
        conf
      end
    end

    def format_body(req, body, content_type)
      case content_type
      when CONTENT_TYPES[:json] then body.to_json
      when CONTENT_TYPES[:xml] then body.to_xml
      when CONTENT_TYPES[:csv] then body.map(&:to_csv).join
      when CONTENT_TYPES[:grpc]
        _, grpc_type = content_type.split('+').last
        if grpc_type == 'json'
          body.to_json
        else
          compressed = 0
          pb_data = api_project.grpc.find_rpc(req.path).output.new(body).to_proto
          flags = [compressed, pb_data.bytesize]
          flags.pack("CN") + pb_data
        end
      when CONTENT_TYPES[:text]
        case body
        when Hash, Array then body.to_json
        else body.to_s
        end
      else
        raise "Cannot handle content_type '#{content_type}'"
      end
    end

    # accept: application/grpc, appalication/json;q=0.8
    # content-type: application/grpc;charset=utf8
    def get_accept_type(req, body)
      if req.content_type.to_s.split(';').first.to_s.strip =~ CONTENT_TYPES[:grpc]
        'application/grpc'
      else
        accepts = req.get_header('accept').to_s.split(',').map { |v| v.split(';').first.strip }
        accepts.each do |type|
          return type if VALID_TYPES.any? { |t| t === type }
        end

        case body
        when Hash, Array then 'application/json'
        else 'text/plain'
        end
      end
    end
  end
end
