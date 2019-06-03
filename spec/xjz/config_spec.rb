RSpec.describe Xjz::Config do
  let(:config) { Xjz::Config.new($config.path) }
  let(:user_dir) { File.join($root, 'tmp/user_idr') }
  let(:user_path) { File.join(user_dir, 'config.yml') }

  before :each do
    `rm -rf #{user_dir}`
    stub_const('Xjz::Config::USER_DIR', user_dir)
    stub_const('Xjz::Config::USER_PATH', user_path)
  end

  after clean_user_dir: true do
    `rm -rf #{user_dir}`
  end

  it '#data should return formatted data' do
    expect(config.data).to eql(
      "alpn_protocols" => ["h2", "http/1.1"],
      "host_whitelist" => ['xjz.com'],
      "logger_level" => { "default" => "debug", 'io' => 'info' },
      "max_threads" => 4,
      "projects" => ["./spec/files/project.yml"],
      "projects_dir" => File.join($root, "tmp/projects_dir_test"),
      "proxy_port" => 59898,
      "proxy_timeout" => 1,
      "proxy_mode" => "whitelist",
      "template_dir" => "./spec/files/webviews",
      "webview_debug" => false,
      "ui_window" => true,
      "home_url" => 'https://xjzproxy.xjz.pw',
      ".user_id" => "xjz",
      ".edition" => "standard",
      ".license_ts" => Time.at(1557830400.5155),
      ".license_ex" => Time.at(2557830399.5154896)
    )
  end

  describe '#load_projects', log: false, stub_config: true do
    let(:pd) { config['projects_dir'] }

    before :each do
      config['projects_dir'] = File.join($root, "tmp/projects_dir_test")
      `rm -rf #{pd}/*`
      `mkdir #{pd}/a; touch #{pd}/a/a.yml`
    end

    after :each do
      `rm -rf #{pd}/*`
    end

    it '#load_projects should return formatted private data' do
      $config['.edition'] = 'pro'
      expect {
        config.load_projects
      }.to change { config.data['.api_projects'] }.to(kind_of(Array))

      expect(config.data['.api_projects'].map(&:repo_path)).to eql(
        config.data['projects'] + ["#{pd}/a"]
      )
    end

    it '#load_projects should return 1 projects if current is free edition' do
      $config['.edition'] = nil

      expect {
        config.load_projects
      }.to change { config.data['.api_projects']&.length || 0 }.to(1)
    end
  end

  it '#[] should return value' do
    expect(config['max_threads']).to eql(4)
    expect(config[:max_threads]).to eql(4)
  end

  it '#[]= should set value' do
    config['max_threads'] = 1
    expect(config['max_threads']).to eql(1)
    config[:max_threads] = 4
    expect(config['max_threads']).to eql(4)
  end

  it '#verify should return empty array for correct config' do
    expect(config.verify).to eql([])
  end

  it '#verify should return errors for invalid config' do
    config.raw_data['logger_level'] = nil
    expect(config.verify).to eql([
      { full_path: "Xjz::Config[\"logger_level\"]", message: "a/an Hash" }
    ])
  end

  it '#to_yaml should return a YAML string of current config' do
    allow(config).to receive(:data).and_return(config.data)
    config['a'] = 123
    config['projects_path'] = '/tmp/a'
    expect(config.changed_to_yaml).to eql(<<~YAML
      ---
      a: 123
      projects_path: "/tmp/a"
    YAML
    )
  end

  it '#shared_data should return a shared data object' do
    expect(config.shared_data.class).to eql(Object)
    expect { config.shared_data.webui = 13 }.to raise_error(/^undefined method `webui=/)
    config.shared_data.webui.ws = 123
    expect(config.shared_data.webui.ws).to eql(123)
  end

  it '#save should save config to user_dir', clean_user_dir: true do
    path = File.join(user_dir, 'config.yml')
    `rm -rf #{user_dir}`
    expect {
      config.save
    }.to change { File.exist?(path) }.to(true)
    expect(File.read(path)).to eql(config.changed_to_yaml)
  end

  describe '#update_license' do
    let(:lpath) { File.join(user_dir, 'license.lcs') }
    let(:path) { "/tmp/xjzproxy.lcs" }

    before :each do
      `rm -rf #{user_dir} #{lpath} #{path}`

      stub_const('Xjz::Config::USER_DIR', user_dir)
      stub_const('Xjz::Config::LICENSE_PATH', lpath)
      allow($config).to receive(:data).and_return({})
    end

    it 'should update license info' do
      `licenses/manager -g #{path} -i xid -e pro`

      expect {
        expect {
          expect($config.update_license(path)).to eql(true)
        }.to change { File.exist?(lpath) }.to(true)
      }.to change {
        $config.data.values_at(*%w{.user_id .edition .license_ex})
      }.to([
        "xid", "pro", nil
      ])
      t = Time.now.to_f
      expect($config['.license_ts'].to_f).to be_between(t - 1, t)
      expect(File.size(File.join(user_dir, 'license.lcs'))).to eql(File.size(path))
    end

    it 'should not update license and return false if license is invalid' do
      expect($config.update_license(path)).to eql(false)
      `echo asdf > #{path}`

      expect($config.update_license(path)).to eql(false)
      expect(File.exist?(lpath)).to eql(false)

      expect($config.data.values_at(*%w{.user_id .edition .license_ts .license_ex})).to \
        eql([nil, nil, nil, nil])
    end

    it 'should not update license and return false if license is invalid' do
      `rm -rf #{path} #{lpath}`
      `licenses/manager -g #{path} -i xid -e pro -t 12`

      expect($config.update_license(path)).to eql(true)
      expect(File.exist?(lpath)).to eql(true)
      expect($config.data.values_at(*%w{.user_id .edition .license_ts .license_ex})).to_not \
        eql([nil, nil, nil, nil])

      `rm -rf #{path} #{lpath}`
      travel_to(Time.now + 13)
      allow($config).to receive(:data).and_return({})
      expect($config.update_license(path)).to eql(false)
      expect(File.exist?(lpath)).to eql(false)

      expect($config.data.values_at(*%w{.user_id .edition .license_ts .license_ex})).to \
        eql([nil, nil, nil, nil])
    end
  end

  describe 'read/write/clean user file' do
    it 'write/read should working' do
      expect($config.write_user_file('a', 'hello')).to eql(true)
      expect($config.read_user_file('a')).to eql('hello')
    end

    it 'write/clean/read should working' do
      expect($config.write_user_file('a', 'hello')).to eql(true)
      $config.clean_user_file('a')
      expect($config.read_user_file('a')).to eql(nil)
    end
  end

  describe '#projects_check', stub_config: true do
    let(:ap1) { double(:ap, data: { 'apis' => [] }, errors: []) }
    let(:ap2) { double(:ap, data: { 'apis' => [] }, errors: []) }
    let(:ap3) { double(:ap, data: { 'apis' => [] }, errors: []) }

    it 'should remove apis if apis count over free edition' do
      $config['.edition'] = nil
      [ap1, ap2, ap3].each do |ap|
        allow(ap).to receive(:data).and_return('apis' => [{}] * 100)
        allow(ap).to receive(:raw_data).and_return(ap.data)
      end

      config['.api_projects'] = [ap1, ap2, ap3]
      expect {
        config.projects_check
      }.to change { config['.api_projects'].sum { |ap| ap.data['apis'].count } }.to(128)
    end

    it 'should remove apis if apis count over standard edition' do
      $config['.edition'] = 'standard'
      [ap1, ap2, ap3].each do |ap|
        allow(ap).to receive(:data).and_return('apis' => [{}] * 200)
        allow(ap).to receive(:raw_data).and_return(ap.data)
      end

      config['.api_projects'] = [ap1, ap2, ap3]
      expect {
        config.projects_check
      }.to change { config['.api_projects'].sum { |ap| ap.data['apis'].count } }.to(512)
    end

    it 'should not remove apis for pro edition' do
      $config['.edition'] = 'pro'
      [ap1, ap2, ap3].each do |ap|
        allow(ap).to receive(:data).and_return('apis' => [{}] * 200)
        allow(ap).to receive(:raw_data).and_return(ap.data)
      end

      config['.api_projects'] = [ap1, ap2, ap3]
      expect {
        config.projects_check
      }.to_not change { config['.api_projects'].sum { |ap| ap.data['apis'].count } }
    end
  end
end
