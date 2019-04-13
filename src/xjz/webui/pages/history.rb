module Xjz
  WebUI::ActionRouter.register do
    namespace 'history' do
      event(/^req\.(?<req_id>\d+)\.click$/) do
        req_id = match_data['req_id'].to_i
        rt = Tracker.instance.history.find { |h| h.request.object_id == req_id }
        send_msg(
          'el.html',
          selector: '#history_detail',
          html: render('webui/_history_detail.html', request_tracker: rt)
        )
      end

      event 'clear_all' do
        Tracker.instance.clear_all
        send_msg(
          'el.html',
          selector: '#t_history',
          html: render('webui/_history_page.html')
        )
      end
    end
  end
end
