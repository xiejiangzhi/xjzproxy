class WebUI
  attr_reader :env, :template_dir

  def initialize(env)
    @env = env
    @template_dir = $config['template_dir'] || File.join($root, 'src/views')
  end

  def process
    body = fetch_template('index').render(Struct.new(:history, :proxy).new([], []))

    [200, {}, [body]]
  end

  def fetch_template(name)
    Slim::Template.new(File.join(template_dir, "#{name}.slim"))
  end
end
