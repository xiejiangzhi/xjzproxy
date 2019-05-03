module Xjz
  WebUI::ActionRouter.register do
    namespace 'project' do
      event(/^detail_tab\.(?<ap_id>\d+)\.click$/) do
        ap_id = match_data['ap_id'].to_i
        ap = $config['.api_projects'].find { |obj| obj.object_id == ap_id }
        errors = ap.errors
        if errors
          send_msg(
            'el.html',
            selector: '#project_detail',
            html: render('webui/project/detail.html', errors: errors, doc_html: nil)
          )
        else
          markdown_str = Xjz::ApiProject::DocRenderer.new(ap).render
          doc_html = Redcarpet::Markdown.new(
            Redcarpet::Render::HTML,
            autolink: true, tables: true, fenced_code_blocks: true
          ).render(markdown_str)
          send_msg(
            'el.html',
            selector: '#project_detail',
            html: render('webui/project/detail.html', doc_html: doc_html, errors: nil)
          )
        end
      end
    end
  end
end
