module Xjz
  WebUI::ActionRouter.register do
    namespace 'report' do
    end

    event 't_report.click' do
      send_msg('el.html', selector: '#t_report', html: render('webui/report/index.html'))
    end
  end
end
