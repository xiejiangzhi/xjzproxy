module Xjz
  class RequestFilter
    attr_reader :filters_str

    OPTS_MAPPING = Hash[[
      '> >', '< <', '<= <=', '>= >=', '= ==', '!= !=',
      '~ =~', '!~ !~'
    ].map(&:split)]

    OPTS = {
      Integer => %w{> >= < <= =},
      Float => %w{> >= < <= =},
      String => %w{= != ~ !~}
    }

    def initialize(str)
      @filters_str = str.to_s.downcase
    end

    def filters
      @filters ||= filters_str.split.map do |part|
        if md = part.match(/^(status|method|type)(=|>=|>|<=|<|!=|~)(.+)$/)
          md[1..-1]
        else
          part
        end
      end
    end

    def valid?(req:, res: nil)
      filters.all? do |ft|
        if String === ft
          compare_vals(req.host, '~', ft) || compare_vals(req.path, '~', ft)
        else
          key, opt, val = ft
          case key
          when 'status' then compare_vals(res.code, opt, val)
          when 'method' then compare_vals(req.http_method, opt, val)
          when 'type'
            compare_vals(req.content_type, opt, val) ||
              compare_vals(res&.content_type, opt, val)
          else
            false
          end
        end
      end
    end

    private

    def compare_vals(a, opt, b)
      opts = OPTS[a.class]
      unless opts
        a = a.to_s
        opts = OPTS[a.class]
      end

      return false unless OPTS[a.class].include?(opt)

      b = Regexp.new(b, 'i') if opt == '~'
      b = b.to_i if Integer === a
      b = b.to_f if Float === a
      a.send(OPTS_MAPPING[opt], b)
    end
  end
end
