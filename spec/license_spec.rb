load File.join($root, 'licenses/xjz_license.rb')

RSpec.describe XJZLicense do
  let(:pkey_path) { File.join($root, 'tmp/test_license_key') }
  let(:subject) { described_class.new(pkey_path) }

  before :each do
    stub_const('XJZLicense::KEY_SIZE', 1024 * 4)
    FileUtils.rm_f(pkey_path)
  end

  it 'encrypt/decrypt should work' do
    data = %w{diff req_res grpc}
    l = subject.generate_license('idxxx', data)
    expect(l.length).to eql(512)
    expect(subject.decrypt(l)).to eql(['idxxx'] + data)
    expect(subject.decrypt(l + 'a')).to eql(nil)
  end

  it 'encrypt should raise error if give invalid data' do
    data = %w{diff a b}
    expect {
      subject.generate_license('idxxx', data)
    }.to raise_error("Invalid flags: a, b")
  end

  it 'decrypt should return nil if give invalid data' do
    data = %w{diff req_res grpc}
    l = subject.generate_license('idxxx', data)
    l[123] = 'a'
    expect(subject.decrypt(l)).to eql(nil)
  end
end
