RSpec.describe 'builder/compile', stub_config: true do
  let(:file) { File.join($root, 'builder/compile') }

  it 'license_checker should return true for matched edition' do
    $config['.user_id'] = 'test123'
    $config['.edition'] = 'pro123'

    ENV['XJZ_TEST_CALL'] = "license_checker('standard')"

    code = `ruby #{file}`.gsub(/.*==BEGIN==(.+)==END==/m, '\1')
    expect {
      expect(eval(code)).to eql(true)
      puts $config.data['.license_ex'].to_f
    }.to change {
      $config.data.values_at(*%w{.user_id .edition .license_ex})
    }.to(["xjz", "standard", Time.at(2557830399.5154896)])

  end

  it 'license_checker should return false for invalid edition' do
    $config['.user_id'] = 'test123'
    $config['.edition'] = 'pro123'

    ENV['XJZ_TEST_CALL'] = "license_checker('pro')"

    code = `ruby #{file}`.gsub(/.*==BEGIN==(.+)==END==/m, '\1')
    expect {
      expect(eval(code)).to eql(false)
    }.to change {
      $config.data.values_at(*%w{.user_id .edition .license_ex})
    }.to(["xjz", "standard", Time.at(2557830399.5154896)])
  end

  it 'license_online_checker should not raise error' do
    ENV['XJZ_TEST_CALL'] = "license_online_checker()"

    code = `ruby #{file}`.gsub(/.*==BEGIN==(.+)==END==/m, '\1')
    # don't raise error
    expect(eval(code)).to eql(true)
  end
end
