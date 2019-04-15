module Xjz
  WebUI::ActionRouter.register do
    namespace 'server' do
      event 'new_request' do
        total_reqs = Xjz::Tracker.instance.history.count
        send_msg('el.html', selector: '#navbar_total_requests', html: total_reqs)
        # send_msg('el.append', selector: '#navbar_total_requests', html: total_reqs)
      end
    end
  end
end
