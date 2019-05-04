module Xjz
  module PageActions::ProjectHelper
    def add_project(path)
      ap = ApiProject.new(path)
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

    def del_project(ap)
      $config['.api_projects'].delete(ap)
      send_msg('el.remove', selector: "#project_tab_#{ap.object_id}")
      if ap == session[:current_project]
        send_msg('el.html', selector: "#project_detail", html: '')
      end
      send_msg('alert', message: "Removed project #{File.basename(ap.repo_path)}")
    end

    def reload_project(ap)
      ap.reload
      send_msg(
        'el.replace',
        selector: "#project_tab_#{ap.object_id}",
        html: render('webui/project/doc_tab.html', ap: ap, active: ap == session[:current_project])
      )
      show_project(ap) if ap == session[:current_project]
      send_msg('alert', message: "Updated project #{File.basename(ap.repo_path)}")
    end

    def show_project(ap)
      errors = ap.errors
      session[:current_project] = ap
      if errors.present?
        send_msg(
          'el.html',
          selector: '#project_detail',
          html: render('webui/project/detail.html', errors: errors, doc_html: nil)
        )
      else
        markdown_str = Xjz::ApiProject::DocRenderer.new(ap).render('md', header: false)
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
