require 'json'
require 'csv'

module Xjz
  class ApiProject::ResponseRenderer
    CONTENT_TYPES = {
      json: 'application/json',
      xml: 'application/xml',
      csv: 'text/csv',
      grpc: /\Aapplication\/grpc(\-web)?(\+(proto|json))?\Z/
    }
    VALID_TYPES = CONTENT_TYEPS.values

    attr_reader :api_project

    def initialize(ap)
      @api_project = ap
    end

    def render(req, res_conf)
      headers = render_headers(res_conf['headers'])
      ct = HTTPHelper.get_header(headers, 'content-type')
      unless ct
        ct = get_accept_type(req, res_conf['data'])
        HTTPHelper.set_header(headers, 'content-type', ct)
      end

      body = render_body(res_conf['data'])
      body = format_body(body, ct)
      Response.new(headers, body, res_conf['http_code'] || 200)
    end

    def render_headers(conf)
      (conf || []).map do |k, v|
        [k.to_s.downcase.tr('_', '-'), v]
      end
    end

    def render_body(conf, depth = 200)
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

    def format_body(headers, body, content_type)
      case content_type
      when CONTENT_TYPES[:json] then body.to_json
      when CONTENT_TYPES[:xml] then body.to_xml
      when CONTENT_TYPES[:csv] then body.map(&:to_csv).join
      when CONTENT_TYPES[:grpc]
        body.to_json
      else
        raise "Cannot handle content_type '#{content_type}'"
      end
    end

    # accept: application/grpc, appalication/json;q=0.8
    # content-type: application/grpc;charset=utf8
    def get_accept_type(req, body)
      if req.content_type.to_s.split(';').strip =~ CONTENT_TYPES[:grpc]
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
