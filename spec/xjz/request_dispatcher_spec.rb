RSpec.describe Xjz::RequestDispatcher, stub_config: true do
  let(:env) do
    {
      "rack.errors" => 'error.io',
      "rack.multithread" => true,
      "rack.multiprocess" => false,
      "rack.run_once" => false,
      "SCRIPT_NAME" => "",
      "QUERY_STRING" => "a=123",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "SERVER_SOFTWARE" => "puma 3.12.0 Llamas in Pajamas",
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "REQUEST_METHOD" => "GET",
      "REQUEST_URI" => "http://baidu.com/",
      "HTTP_HOST" => "baidu.com",
      "HTTP_USER_AGENT" => "curl/7.54.0",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_PROXY_CONNECTION" => "Keep-Alive",
      "HTTP_CONTENT_TYPE" => "text/plain; charset=utf-8",
      "HTTP_CONNECTION" => "keep-alive",
      "SERVER_NAME" => "baidu.com",
      "SERVER_PORT" => "80",
      "REQUEST_PATH" => "/asdf",
      "PATH_INFO" => "/asdf",
      "REMOTE_ADDR" => "127.0.0.1",
      "rack.hijack?" => true,
      "rack.hijack" => proc { 'user_socket' },
      "rack.hijack_io" => 'user_socket',
      "rack.input" => StringIO.new('hello'),
      "rack.url_scheme" => "http",
    }
  end

  describe 'call' do
    let(:fr) { double('forward', perform: true) }
    let(:sslr) { double('ssl', perform: true) }
    let(:h1r) { double('http1', perform: true) }
    let(:h2r) { double('http2', perform: true) }
    let(:webr) { double('webui', perform: true) }

    def init_checker(r, n = 1, ap = nil)
      [
        [Xjz::Resolver::Forward, fr],
        [Xjz::Resolver::SSL, sslr],
        [Xjz::Resolver::HTTP1, h1r],
        [Xjz::Resolver::HTTP2, h2r],
        [Xjz::Resolver::WebUI, webr],
      ].each do |cls, v|
        if r == v
          expect(cls).to receive(:new).with(kind_of(Xjz::Request), ap).and_return(v).exactly(n).times
          expect(v).to receive(:perform).exactly(n).times
        else
          expect(cls).to_not receive(:new)
        end
      end
    end

    after :each do
      $config['proxy_mode'] = 'projects'
    end

    describe 'whitelist mode' do
      before :each do
        $config['proxy_mode'] = 'whitelist'
      end

      it 'should process conn if host belongs to project' do
        init_checker(h2r, 1, $config['.api_projects'][0])
        env['HTTP_HOST'] = 'xjz.pw'
        env['REQUEST_METHOD'] = 'PRI'
        subject.call(env)
      end

      it 'should process conn if host is in whitelist' do
        init_checker(h1r)
        env['HTTP_HOST'] = 'xjz.com'
        env['REQUEST_METHOD'] = 'post'
        subject.call(env)
      end

      it 'should forward conn other host' do
        init_checker(fr)
        env['HTTP_HOST'] = 'xjz123.com'
        env['REQUEST_METHOD'] = 'post'
        subject.call(env)
      end
    end

    describe 'all mode' do
      before :each do
        $config['proxy_mode'] = 'all'
      end

      it 'should process all conn' do
        init_checker(h1r)
        init_checker(h1r, 1, $config['.api_projects'][0])
        init_checker(h1r)
        env['HTTP_HOST'] = 'hello.com'
        subject.call(env)

        env['HTTP_HOST'] = 'xjz.pw'
        subject.call(env)

        env['HTTP_HOST'] = 'asdf123.pw'
        subject.call(env)
      end
    end

    describe 'upgrade connection' do
      before :each do
        $config['proxy_mode'] = 'all'
      end

      it 'should forward websock' do
        init_checker(fr)
        env['HTTP_UPGRADE'] = 'websocket'
        subject.call(env)
      end

      it 'should handle h2c' do
        init_checker(h2r, 1)
        env['HTTP_UPGRADE'] = 'h2c'
        subject.call(env)
      end

      it 'should not handle other upgrade' do
        init_checker(fr, 0)
        env['HTTP_UPGRADE'] = 'other'
        subject.call(env)
      end
    end

    it 'should process with webui for a local request' do
      data = $config.data.dup.merge!(
        'proxy_mode' => 'whitelist',
        'host_whitelist' => [],
        'projects' => [],
        '.api_projects' => [],
      )
      allow($config).to receive(:data).and_return(data)
      init_checker(webr)
      env['REQUEST_URI'] = '/'
      sock = double('socket', ia_a?: false)
      env['rack.hijack_io'] = sock
      expect(sock).to receive(:is_a?) do |cls|
        expect(cls).to eql(TCPSocket)
        true
      end
      subject.call(env)
    end

    it 'should find api_project by host' do
      $config['.edition'] = 'standard'
      ap = $config['.api_projects'][0]
      ap2 = Xjz::ApiProject.new(File.join($root, 'spec/files/grpc.yml'))
      $config['.api_projects'] << ap2
      env['HTTP_HOST'] = 'xjz.pw'
      expect(subject).to receive(:dispatch_request).with(ap, kind_of(Xjz::Request))
      subject.call(env)

      env['HTTP_HOST'] = 'grpc.xjz.pw'
      expect(subject).to receive(:dispatch_request).with(ap2, kind_of(Xjz::Request))
      subject.call(env)
    end

    describe 'app edition' do
      it 'should return first project for free edition' do
        $config['.edition'] = nil
        ap = $config['.api_projects'][0]
        ap2 = Xjz::ApiProject.new(File.join($root, 'spec/files/grpc.yml'))
        $config['.api_projects'] << ap2
        env['HTTP_HOST'] = 'xjz.pw'
        expect(subject).to receive(:dispatch_request).with(ap, kind_of(Xjz::Request))
        subject.call(env)

        env['HTTP_HOST'] = 'grpc.xjz.pw'
        expect(Xjz::Resolver::Forward).to receive(:new).and_return(double('fr', perform: nil))
        expect(subject).to_not receive(:dispatch_request)
        subject.call(env)
      end
    end
  end
end
