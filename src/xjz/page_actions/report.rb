module Xjz
  WebUI::ActionRouter.register :report do
    namespace 'report' do
    end

    event 'f_report_tab.click' do
      session[:current_tab] = :report
      send_msg('el.html', selector: '#f_report', html: render('webui/report/index.html'))
    end
  end
end
