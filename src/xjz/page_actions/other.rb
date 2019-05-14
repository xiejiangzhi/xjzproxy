module Xjz
  WebUI::ActionRouter.register :other do
    namespace 'other' do
      event 'open_buy_page.click' do
        url = $config['home_url']
        opened = false

        case Gem::Platform.local.os
        when 'darwin'
          Kernel.system("open #{url}")
          opened = true
        else
          %w{xdg-open firefox google-chrome}.each do |cmd|
            next unless Kernel.system("which #{cmd}")
            Kernel.system("#{cmd} #{url}")
            opened = true
            break
          end
        end

        unless opened
          Logger[:auto].error { "Failed to open home url" }
          send_msg(
            'alert',
            type: :error,
            message: "Failed to open #{url} . please copy it to browser to open"
          )
        end
      end

      event 'new_license_path.change' do
        if $config.update_license(data[:value])
          $config.save
        else
          send_msg(
            'alert',
            type: :error,
            message: "Failed to update license, " +
              "Please make sure the file is a valid license and try again"
          )
        end
      end
    end

    event 'f_other_tab.click' do
      session[:current_tab] = :other
    end
  end
end
