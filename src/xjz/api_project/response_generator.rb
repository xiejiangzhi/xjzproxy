require 'json'
require 'csv'

module Xjz
  module ApiProject::ResponseGenerator
    extend self

    JSON_TYPE = 'application/json'
    XML_TYPE = 'application/xml'
    CSV_TYPE = 'text/csv'

    def generate(res_conf)
      body = render_body(res_conf['data'])
      headers = render_headers(res_conf['headers'])
      body = format_body(headers, body)
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
          next if k[0..1] == './'
          r[k] = render_body(v, depth - 1)
        end
      when Array
        conf.map { |v| render_body(v, depth - 1) }
      else
        conf
      end
    end

    def format_body(headers, body)
      content_type = HTTPHelper.get_header(headers, 'content-type')

      case content_type
      when JSON_TYPE
        body.to_json
      when XML_TYPE
        body.to_xml
      when CSV_TYPE
        body.map(&:to_csv).join
      else
        case body
        when Hash, Array
          HTTPHelper.set_header(headers, 'content-type', JSON_TYPE) if content_type.nil?
          body.to_json
        else
          HTTPHelper.set_header(headers, 'content-type', 'text/plain') if content_type.nil?
          body.to_s
        end
      end
    end
  end
end
