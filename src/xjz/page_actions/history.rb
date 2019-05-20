module Xjz
  WebUI::ActionRouter.register :history do
    helpers do
      def update_rt_list
        send_msg(
          'el.html',
          selector: '#history_rt_list_group',
          html: render('webui/history/rt_list.html')
        )
      end

      def get_group_id(req)
        case session[:history_group_by]
        when 'host' then "rt_host_#{Base64.strict_encode64(req.host).tr('=', '')}"
        when 'conn' then "rt_conn_#{req.user_socket.object_id}"
        end
      end

      def total_grouped_reqs(req)
        gb = session[:history_group_by]
        Tracker.instance.history.count do |trt|
          (gb == 'host' && trt.request.host == req.host) ||
            (gb == 'conn' && trt.request.user_socket.object_id == req.user_socket.object_id)
        end
      end

      def req_filter
        session[:history_filter] ||= RequestFilter.new('')
      end
    end

    event 'f_history_tab.click' do
      session[:current_tab] = :history
    end

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

      event 'group_by.change' do
        session[:history_group_by] = data[:value]
        update_rt_list
      end

      event(/^filter\.(keyup|change)$/) do
        next if data[:value] == req_filter.filters_str
        session[:history_filter] = RequestFilter.new(data[:value])
        update_rt_list
      end

      event 'detail_tab.click' do
        next if data[:name] == session[:history_detail_tab]
        session[:history_detail_tab] = data[:name]
      end

      event 'update_total_proxy_conns' do
        send_msg(
          'el.html',
          selector: '#navbar_total_conns',
          html: $config.shared_data.app.server.total_proxy_conns.to_s
        )
      end
    end

    namespace 'server.tracker' do
      # Data:
      #   rt: request tracker
      event 'new_request' do
        history = Tracker.instance.history
        total_reqs = history.count
        send_msg('el.html', selector: '#navbar_total_requests', html: total_reqs.to_s)
        send_msg(
          'el.html',
          selector: '#navbar_total_conns',
          html: $config.shared_data.app.server.total_proxy_conns.to_s
        )

        rt = data[:rt]
        req = rt.request
        next unless req_filter.valid?(req: req, res: rt.response)

        group_id = get_group_id(req)
        req_tab_proc = proc {
          render 'webui/history/request_tab.html', request_tracker: rt, group_id: group_id
        }

        if group_id.present?
          if total_grouped_reqs(req) <= 1
            send_msg(
              'el.append',
              selector: "#history_rt_list_group",
              html: render(
                'webui/history/request_group_tab.html',
                request: req, group_id: group_id, &req_tab_proc
              )
            )
          else
            send_msg('el.append', selector: "[data-rt-group=#{group_id}]", html: req_tab_proc.call)
          end
        else
          send_msg('el.append', selector: "#history_rt_list_group", html: req_tab_proc.call)
        end
      end

      # Data:
      #   rt: request tracker
      event 'update_request' do
        rt = data[:rt]
        req = rt.request
        next unless req_filter.valid?(req: req, res: rt.response)

        html = render(
          'webui/history/request_tab.html',
          request_tracker: rt, group_id: get_group_id(req)
        )
        send_msg('el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: html)

        if session[:current_rt] == rt
          html = render 'webui/history/detail.html', request_tracker: rt
          send_msg('el.html', selector: "#history_detail", html: html)
        end
      end
    end
  end
end
