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
        history = Xjz::Tracker.instance.history
        total_reqs = history.count
        send_msg('el.html', selector: '#navbar_total_requests', html: total_reqs)

        rt = data[:rt]
        req = rt.request
        total_reqs_of_conn = history.count do |trt|
          trt.request.user_socket.object_id == req.user_socket.object_id
        end
        if total_reqs_of_conn <= 1
          html = render 'webui/history/request_group_tab.html', request: req
          send_msg('el.append', selector: "#history_rt_list_group", html: html)
        end

        html = render 'webui/history/request_tab.html', request_tracker: rt
        selector = "[data-rt-group=request_group_tab_#{rt.request.user_socket.object_id}]:last"
        send_msg('el.after', selector: selector, html: html)
      end

      # Data:
      #   rt: request tracker
      event 'update_request' do
        rt = data[:rt]
        html = render 'webui/history/request_tab.html', request_tracker: rt
        send_msg('el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: html)

        if session[:current_rt] == rt
          html = render 'webui/history/detail.html', request_tracker: rt
          send_msg('el.html', selector: "#history_detail", html: html)
        end
      end
    end
  end
end
