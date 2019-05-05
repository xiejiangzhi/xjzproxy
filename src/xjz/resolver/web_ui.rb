module Xjz
  class Resolver::WebUI
    attr_reader :req, :template_dir, :api_project

    NOT_FOUND_RES = [{ 'Connection' => 'close' }, ["Not Found"], 404]

    def initialize(req, ap = nil)
      @api_project = ap
      @req = req
    end

    def perform
      Logger[:auto].info { "Perform by WebUI" }
      res = perform_req(req)
      return if res.nil? || res.conn_close?

      parser = HTTPParser.new
      close_conn = false
      user_socket = req.user_socket
      parser.on_finish do |env|
        HTTPHelper.write_conn_info_to_env!(env, user_socket)
        res = perform_req(Request.new(env))
        close_conn = res.conn_close?
      end

      IOHelper.forward_streams(
        { user_socket => WriterIO.new(parser) },
        stop_wait_cb: proc { close_conn }
      )
    end

    def perform_req(req)
      headers, body, status = case req.path
      when '/root_ca.pem'
        msg_download_res(Resolver::SSL.cert_manager.root_ca.to_pem, 'xjzproxy_root_ca.pem')
      when '/root_ca.crt'
        msg_download_res(Resolver::SSL.cert_manager.root_ca.to_pem, 'xjzproxy_root_ca.crt')
      when '/status'
        [{}, ['Ready'], 200]
      when '/'
        body = $config.shared_data.app.webui.render('webui/index.html')
        [{}, [body], 200]
      when '/ws'
        if req.upgrade_flag == 'websocket'
          ws = WebUI::WebSocket.new(req)
          $config.shared_data.app.webui.watch(ws)
          $config.shared_data.webui.ws = ws
          return if ws.perform
        end
        [{}, ['Failed to perform websocket'], 400]
      when %r{\A/static/.+(js|css|png|svg|woff|woff2|ttf)\Z}
        path = File.join($root, 'src', req.path)
        content_type = case path
        when /js$/ then 'text/javascript'
        when /css$/ then 'text/css'
        when /png$/ then 'image/png'
        end
        if File.exist?(path)
          [{ 'content-type' => content_type }.compact, [File.read(path)], 200]
        else
          NOT_FOUND_RES
        end
      else
        NOT_FOUND_RES
      end

      if headers && body && status
        headers['Connection'] = req.get_header('connection')
        Response.new(headers, body, status).tap do |res|
          HTTPHelper.write_res_to_conn(res, req.user_socket)
        end
      end
    end

    private

    def msg_download_res(msg, filename)
      [
        {
          'Content-Type' => 'application/octet-stream; charset=utf-8',
          'Content-Disposition' => %Q{attachment; filename="#{filename}"},
          "Connection" => 'close'
        },
        [msg], 200
      ]
    end
  end
end
