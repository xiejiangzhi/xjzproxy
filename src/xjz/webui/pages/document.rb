module Xjz
  WebUI::ActionRouter.register do
    namespace 'document' do
      event(/^ap\.(?<ap_id>\d+)\.click$/) do
        ap_id = match_data['ap_id'].to_i
        ap = $config['.api_projects'].find { |obj| obj.object_id == ap_id }
        markdown_str = Xjz::ApiProject::DocRenderer.new(ap).render
        doc_html = Redcarpet::Markdown.new(
          Redcarpet::Render::HTML,
          autolink: true, tables: true, fenced_code_blocks: true
        ).render(markdown_str)
        send_msg(
          'el.html',
          selector: '#document_detail',
          html: render('webui/_document_detail.html', doc_html: doc_html)
        )
      end
    end
  end
end
