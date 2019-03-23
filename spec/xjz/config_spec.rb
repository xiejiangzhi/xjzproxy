RSpec.describe Xjz::Config do
  describe '#data' do
    it 'should return formatted data' do
      expect($config.data.select { |k, v| k[0] != '.' }).to eql(
        "alpn_protocols" => ["h2", "http/1.1"],
        "host_blacklist" => ['hello.com'],
        "host_whitelist" => ['xjz.com'],
        "key_path" => "tmp/key.pem",
        "logger_level" => { "default" => "debug", 'io' => 'info' },
        "max_threads" => 4,
        "projects" => ["./spec/files/project.yml"],
        "proxy_port" => 59898,
        "proxy_timeout" => 1,
        "proxy_mode" => "projects",
        "root_ca_path" => "tmp/root_ca.pem"
      )
    end

    it 'should return formatted private data' do
      expect($config.data['.api_projects'].map(&:repo_path)).to eql(
        $config.data['projects']
      )
    end
  end

  it '#[] should return value' do
    expect($config['max_threads']).to eql(4)
    expect($config[:max_threads]).to eql(4)
  end

  it '#[]= should set value' do
    $config['max_threads'] = 1
    expect($config['max_threads']).to eql(1)
    $config[:max_threads] = 4
    expect($config['max_threads']).to eql(4)
  end

  it '#verify should return empty array for correct config' do
    expect($config.verify).to eql([])
  end

  it '#verify should return errors for invalid config' do
    t = $config.raw_data['logger_level']
    $config.raw_data['logger_level'] = nil
    expect($config.verify).to eql([
      { full_path: "Xjz::Config[\"logger_level\"]", message: "a/an Hash" }
    ])
    $config.raw_data['logger_level'] = t
  end
end
