module Xjz
  WebUI::ActionRouter.register do
    namespace 'history' do
      event(/^detail\.(?<req_id>\d+)\.click$/) do
        req_id = match_data['req_id'].to_i
        rt = Tracker.instance.history.find { |h| h.object_id == req_id }
        send_msg(
          'el.html',
          selector: '#history_detail',
          html: render('webui/history/detail.html', request_tracker: rt)
        )
      end

      event 'clean_all.click' do
        Tracker.instance.clean_all
        send_msg('el.html', selector: '#navbar_total_requests', html: 0)
        send_msg(
          'el.html',
          selector: '#f_history',
          html: render('webui/history/index.html')
        )
      end
    end
  end
end
