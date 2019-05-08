module Xjz
  module ProjectRender
    def self.text_to_id(text)
      text.gsub(/<[^>]+>|[^\w-]+/, ' ').strip.gsub(/\s+/, '-')
    end

    def self.strip_html(text)
      text.gsub(/<[^>]+>[^>]+>|[^\w-]+/, ' ').strip.gsub(/\s{2,}/, ' ')
    end

    class HTML < Redcarpet::Render::HTML
      def header(text, header_level)
        "<h#{header_level} id='#{ProjectRender.text_to_id(text)}'>#{text}</h#{header_level}>"
      end

      def table(header, body)
        html = "<table class='table'><thead>"
        html << header.to_s
        html << "</thead>"
        html << "<tbody>"
        html << body.to_s
        html << "</tbody></table>"
        html
      end

      def block_code(code, lang)
        html = "<pre><code class='#{lang}'>"
        html << code
        html << "</code></pre>"
        html
      end
    end

    class HTML_TOC < Redcarpet::Render::HTML_TOC
      def header(text, header_level)
        @base_level ||= header_level
        level = header_level - @base_level
        id = ProjectRender.text_to_id(text)
        title = ProjectRender.strip_html(text)
        "<a class='list-group-item list-group-item-action toc-level-#{level}'" \
          " href='##{id}'>#{title}</a>"
      end

      def postprocess(doc)
        cid = @options[:container_id] || @options['container_id']
        id = cid ? "id='#{cid}'" : nil
        "<div class='list-group' #{id}>#{doc}</div>"
      end
    end
  end
end
