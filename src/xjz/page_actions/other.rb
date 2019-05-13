module Xjz
  WebUI::ActionRouter.register :other do
    namespace 'other' do
    end

    event 'f_other_tab.click' do
      session[:current_tab] = :other
    end
  end
end
