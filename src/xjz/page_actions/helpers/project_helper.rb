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
        html: render('webui/project/doc_tab.html', ap: ap)
      )
      show_project(ap) if ap == session[:current_project]
      send_msg('alert', message: "Updated project #{File.basename(ap.repo_path)}")
    end

    def show_project(ap, toc: false)
      if session[:project_focus_toc] && toc
        send_msg(
          'el.html',
          selector: '#project_left',
          html: render('webui/project/detail_toc.html', ap: ap)
        )
      end
      send_msg(
        'el.html',
        selector: '#project_detail',
        html: render('webui/project/detail.html', ap: ap)
      )
    end
  end
end
