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

    def render(req, res_conf)
      res_conf ||= {}
      headers = render_headers(res_conf['headers'])
      ct = HTTPHelper.get_header(headers, 'content-type')
      unless ct
        ct = get_accept_type(req, res_conf['data'])
        HTTPHelper.set_header(headers, 'content-type', ct)
      end

      res_conf['data'] ||= generate_grpc_scheme(req) if CONTENT_TYPES[:grpc] === ct

      body = render_body(res_conf['data'])
      body = format_body(req, body, ct)

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
          find_rpc(req).output.new(body).to_proto
        end
      when CONTENT_TYPES[:text]
        body.to_s
      else
        raise "Cannot handle content_type '#{content_type}'"
      end
    end

    # accept: application/grpc, appalication/json;q=0.8
    # content-type: application/grpc;charset=utf8
    def get_accept_type(req, body)
      if req.content_type.to_s.split(';').first.strip =~ CONTENT_TYPES[:grpc]
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

    def generate_grpc_scheme(req)
      rpc = find_rpc(req)
      fetch_schema_of_pb_desc(rpc.output.descriptor)
    end

    def fetch_schema_of_pb_desc(pbd)
      types = api_project.data['types']
      pbd.each_with_object({}) do |field, r|
        # https://developers.google.com/protocol-buffers/docs/proto3#scalar
        type = case field.type
        when :float, :double
          types['float']
        when :int32, :int64, :uint32, :uint64, :sint32, :sint64, :fixed32, :fixed64, :sfixed32, :sfixed64
          types['integer']
        when :bool
          types['boolean']
        when :string, :bytes
          types['string']
        when :enum
          field.subtype.to_a.sample.last
        when :message
          fetch_schema_of_pb_desc(field.subtype)
        else
          raise "Unsuppoerted type '#{field.type}'"
        end

        r[field.name] = (field.label == :repeated) ? [type] : type
      end
    end

    def find_rpc(req)
      m = api_project.data['project']['.grpc_module']
      m.services[req.path] ||= begin
        service, action = req.path[1..-1].split('/')
        service_name = service.split('.').map(&:camelcase).join('::') + '::Service'

        scls = begin
          m.const_get(service_name)
        rescue NameError => e
          raise "Not found service by '#{service_name}'"
        end

        scls.rpc_descs[action.to_sym].tap do |rpc|
          raise "Not found RPC method by #{service}/#{action}" unless rpc
        end

      end
    end
  end
end
