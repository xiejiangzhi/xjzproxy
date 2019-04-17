module Xjz
  WebUI::ActionRouter.register do
    namespace 'history' do
      event(/^detail\.(?<req_id>\d+)\.click$/) do
        req_id = match_data['req_id'].to_i
        rt = Tracker.instance.history.find { |h| h.object_id == req_id }
        session[:current_rt] = rt
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

    namespace 'server.tracker' do
      # Data:
      #   rt: request tracker
      event 'new_request' do
        total_reqs = Xjz::Tracker.instance.history.count
        send_msg('el.html', selector: '#navbar_total_requests', html: total_reqs)
        html = render 'webui/history/_request_tracker_tab.html', request_tracker: data[:rt]
        send_msg('el.append', selector: '#history_rt_list_group', html: html)
      end

      # Data:
      #   rt: request tracker
      event 'update_request' do
        rt = data[:rt]
        html = render 'webui/history/_request_tracker_tab.html', request_tracker: rt
        send_msg('el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: html)

        if session[:current_rt] == rt
          html = render 'webui/history/detail.html', request_tracker: rt
          send_msg('el.html', selector: "#history_detail", html: html)
        end
      end
    end
  end
end
