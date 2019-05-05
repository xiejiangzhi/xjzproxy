module Xjz
  WebUI::ActionRouter.register :project do
    event 'f_project_tab.click' do
      session[:current_tab] = :project
    end

    namespace 'project' do
      event(/^detail_tab\.(?<ap_id>\d+)\.click$/) do
        ap_id = match_data['ap_id'].to_i
        ap = $config['.api_projects'].find { |obj| obj.object_id == ap_id }
        show_project(ap)
      end
    end

    namespace 'server.project' do
      # Params:
      #   path:
      event 'add' do
        add_project(data[:path])
      end

      # Params:
      #   ap: or path
      #   path: ap path
      event 'del' do
        ap = data[:ap] || $config['.api_projects'].find { |v| v.repo_path == data[:path] }
        del_project(ap)
      end

      # Params:
      #   ap: or path
      event 'reload' do
        ap = data[:ap]
        reload_project(ap)
      end
    end

    helpers do
      include PageActions::ProjectHelper
    end

  end
end
