module Xjz
  class Reslover::WebUI
    attr_reader :req, :template_dir

    def initialize(req)
      @req = req
      @template_dir = $config['template_dir'] || File.join($root, 'src/views')
    end

    def perform
      body = fetch_template('index').render(ViewEntity.new(Tracker.instance.history))
      HTTPHelper.write_res_to_conn(Response.new({}, [body], 200), req.user_socket)
    end

    def fetch_template(name)
      Slim::Template.new(File.join(template_dir, "#{name}.slim"))
    end
  end
end
