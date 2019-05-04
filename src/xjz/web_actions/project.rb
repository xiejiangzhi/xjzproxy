module Xjz
  WebUI::ActionRouter.register do
    event 'f_project_tab.click' do
    end

    namespace 'project' do
      event(/^detail_tab\.(?<ap_id>\d+)\.click$/) do
        ap_id = match_data['ap_id'].to_i
        ap = $config['.api_projects'].find { |obj| obj.object_id == ap_id }
        errors = ap.errors
        session[:current_project] = ap
        if errors.present?
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

    namespace 'server.project' do
      # Params:
      #   path:
      event 'add' do
        ap = ApiProject.new(data[:path])
        if ap.files.present?
          $config['.api_projects'] << ap
          send_msg(
            'el.append',
            selector: "#project_list_tabs",
            html: render('webui/project/doc_tab.html', ap: ap)
          )
          send_msg('alert', message: "Added project #{File.basename(ap.repo_path)}")
        end
      end

      # Params:
      #   ap: or path
      #   path: ap path
      event 'del' do
        ap = data[:ap] || $config['.api_projects'].find { |v| v.repo_path == data[:path] }
        $config['.api_projects'].delete(ap)
        send_msg('el.remove', selector: "#project_tab_#{ap.object_id}")
        send_msg('alert', message: "Removed project #{File.basename(ap.repo_path)}")
      end

      # Params:
      #   ap: or path
      event 'reload' do
        ap = data[:ap]
        ap.reload
        send_msg('alert', message: "Updated project #{File.basename(ap.repo_path)}")
        if ap == session[:current_project]

        end
      end
    end
  end
end
