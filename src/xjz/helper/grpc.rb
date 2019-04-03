module Xjz
  class Helper::GRPC
    attr_reader :api_project, :grpc, :rpcs_map, :desc_map

    def initialize(ap)
      @api_project = ap
      @grpc = ap.data['project']['.grpc_module']
      @rpcs_map = {}
      @desc_map = {}
    end

    def find_rpc(path)
      return rpcs_map[path] if rpcs_map.key?(path)

      service, action = path[1..-1].split('/')
      service_name = service.split('.').map(&:camelcase).join('::') + '::Service'

      scls = begin
        grpc.const_get(service_name)
      rescue NameError
        Logger[:auto].debug { "Not found service by '#{service_name}'" }
        rpcs_map[path] = nil
        return
      end

      rpcs_map[path] = scls.rpc_descs[action.to_sym]
      return rpcs_map[path] if rpcs_map[path]
      Logger[:auto].debug { "Not found RPC method by #{service}/#{action}" }
      nil
    end

    def input_desc(path)
      rpc = find_rpc(path)
      return unless rpc
      desc = rpc.input.descriptor
      @desc_map[desc] ||= fetch_schema_of_pb_desc(desc)
    end

    def output_desc(path)
      rpc = find_rpc(path)
      return unless rpc
      desc = rpc.output.descriptor
      @desc_map[desc] ||= fetch_schema_of_pb_desc(desc)
    end

    def res_desc(path)
      desc = output_desc(path)
      api = api_project.find_api('post', 'https', 'grpc.xjz.pw', path)
      res = (api&.dig('response', 'success') || []).sample || {}

      {
        'headers' => res['headers'] || {},
        'http_code' => res['http_code'] || 200,
        'data' => res['data'] || desc
      }
    end

    private

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
  end
end
