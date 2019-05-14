RSpec.describe Xjz::Config do
  let(:config) { Xjz::Config.new($config.path) }
  let(:user_dir) { File.join($root, 'tmp/user_idr') }

  after clean_user_dir: true do
    `rm -rf #{user_dir}`
  end

  it '#data should return formatted data' do
    expect(config.data).to eql(
      "alpn_protocols" => ["h2", "http/1.1"],
      "host_whitelist" => ['xjz.com'],
      "key_path" => "tmp/key.pem",
      "logger_level" => { "default" => "debug", 'io' => 'info' },
      "max_threads" => 4,
      "projects" => ["./spec/files/project.yml"],
      "projects_dir" => File.join($root, "tmp/projects_dir_test"),
      "proxy_port" => 59898,
      "proxy_timeout" => 1,
      "proxy_mode" => "whitelist",
      "root_ca_path" => "tmp/root_ca.pem",
      "template_dir" => "./spec/files/webviews",
      "webview_debug" => false,
      "ui_window" => true,
      "home_url" => 'https://xjz.pw',
      ".user_id" => "xjz",
      ".edition" => "standard",
      ".license_ts" => Time.at(1557830400.5155),
      ".license_ex" => Time.at(2557830399.5154896)
    )
  end

  it '#load_projects should return formatted private data' do
    expect {
      config.load_projects
    }.to change { config.data['.api_projects'] }.to(kind_of(Array))

    expect(config.data['.api_projects'].map(&:repo_path)).to eql(
      config.data['projects']
    )
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

  it '#save should save config to user_dir' do
    path = File.join(user_dir, 'config.yml')
    stub_const('Xjz::Config::USER_DIR', user_dir)
    stub_const('Xjz::Config::USER_PATH', path)
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
end
