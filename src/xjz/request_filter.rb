module Xjz
  class RequestFilter
    attr_reader :filters_str
    def initialize(str)
      @filters_str = str.to_s.downcase
    end

    def filters
      @filters ||= filters_str.split.map do |part|
        if md = part.match(/^(status|method)(=|>=|>|<=|<|!=)(.+)$/)
          md[1..-1]
        else
          part
        end
      end
    end

    def valid?(host:, path:, http_method:, status: nil)
      filters.all? do |ft|
        if String === ft
          host.to_s.downcase.include?(ft) || path.to_s.downcase.include?(ft)
        else
          key, opt, text = ft
          case key
          when 'status' then status.to_i.send(opt, text.to_i)
          when 'method' then http_method.to_s.upcase == text.upcase
          else true
          end
        end
      end
    end
  end
end
