module Xjz
  class ApiProject::DocRenderer
    attr_reader :api_project, :template_dir

    TEMPLATE_PREFIX = 'xjzapidoc'

    def initialize(ap)
      @api_project = ap
    end

    def render(type = 'md', header: true)
      path = "#{TEMPLATE_PREFIX}/index.#{type}"
      Helper::Webview.render(path, {
        'project' => api_project,
        'raw_data' => api_project.raw_data,
        'data' => api_project.data,
        'render_header' => header
      }, [DocViewHelper])
    end

    module DocViewHelper
      def project
        @project ||= vars['project']
      end

      # Params
      #   data:
      #     a: 1
      #     .a:
      #       desc: 123
      #       required: true
      #     b: .t/integer
      #     c: {
      #       a: 123
      #     }
      #     .c: { desc: 'xxx' }
      # Returns
      #   [
      #     ['a', { 'val' => 1, 'desc' => 123, 'required: true }],
      #     ['b', { 'type' => '.t/integer' }]
      #     ['c', { 'type' => 'Hash', 'desc' => 'xxx' }],
      #     ['c.a', { 'val' => 123 }],
      #   ]
      def format_data(data, result = {}, prefix = nil)
        case data
        when Hash
          data.each do |k, v|
            _save_data_line(k, v, result, prefix)
          end
        when Array
          data.each_with_index do |v, i|
            _save_data_line(i.to_s, v, result, prefix)
          end
        else
          _save_data_line('', data, result, prefix)
          # nothing
        end
        result
      end

      def md_escape(str)
        str.gsub('_', '\\_')
      end

      def get_ref_id(ref)
        text = case ref
        when /^\.r\/(.+)$/ then toc_id($1.titleize, [:res])
        when /^\.p\/(.+)$/ then toc_id($1.titleize, [:partial])
        when /^\.t\/(.+)$/ then toc_id($1.titleize, [:type])
        when /^grpc-(.+)$/ then toc_id($1, [:grpc])
        else
          return
        end

        Xjz::ProjectRender.text_to_id(text)
      end

      # call('responses', 'xxname')
      # call('apis', [index, 'success'])
      def render_project_data(category, id)
        ctg = category.to_s
        ctg_data = project.data[ctg]
        data = case ctg
        when 'apis'
          ctg_data.dig(id[0], 'response', id[1], 'data')
        when 'responses'
          ctg_data[id.to_s]['data']
        else
          ctg_data[id.to_s]
        end

        if data
          JSON.pretty_generate(project.response_renderer.render_body(data)).html_safe
        else
          nil
        end
      end

      def grpc_each(&block)
        grpc = project.grpc
        grpc.services.each do |service|
          service.rpc_descs.sort_by(&:first).each do |name, rpc|
            path = "/#{service.service_name}/#{name}"
            input, output = [rpc.input, rpc.output].map do |msg|
              if msg == Google::Protobuf::Empty
                [msg.descriptor.name, nil]
              else
                [msg.descriptor.name, grpc.proto_msg_to_schema(msg)]
              end
            end
            block.call(path, input, output)
          end
        end
      end

      def proto_msg_to_data(proto_msg)
        fetch_schema_of_pb_desc(desc)
      end

      def toc_id(title, ids)
        id = Base64.strict_encode64(ids.join('-')).tr('=', '')
        "<i style='display: none;'>#{id}</i> #{title}"
      end

      def id_tag(tid)
        "<br tid='#{tid}' style='display: none;' />"
      end

      def icon_tag(name, cls = 'title-icon')
        "<i class='#{cls} fas fa-#{name}'></i>"
      end

      def _save_data_line(k, v, result, prefix = nil)
        _, k, *opts_ks = k.split('.') if k[0] == '.'
        rk = if k == '*' # '.*'
          prefix
        else
          prefix ? "#{prefix}[#{k.inspect}]" : k
        end
        r = result[rk] ||= {}

        if opts_ks
          if opts_ks.empty? # use type for '.*'
            r['type'] = v
          else
            opts_ks[1..-2].each do |k|
              r = (r[k] ||= {})
            end
            r[opts_ks[-1]] = v
          end
        elsif v.to_s =~ /^\.\w\//
          val, oper, *args = v.split
          r['type'] = val
          if oper
            r['type_oper'] = oper
            r['type_args'] = args
          end
        elsif v.is_a?(ApiProject::DataType)
          r['type'] = v.name
        else
          case v
          when Hash
            r['type'] = 'hash'
            format_data(v, result, rk)
          when Array
            r['type'] = 'array'
            format_data(v, result, rk)
          else
            r['val'] = v
          end
        end
      end
    end
  end
end
