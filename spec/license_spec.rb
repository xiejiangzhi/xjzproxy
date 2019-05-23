load File.join($root, 'licenses/xjz_license.rb')

RSpec.describe XJZLicense do
  let(:pkey_path) { File.join($root, 'tmp/test_license_key') }
  let(:subject) { described_class.new(pkey_path) }

  before :each do
    stub_const('XJZLicense::KEY_SIZE', 1024 * 4)
    FileUtils.rm_f(pkey_path)
  end

  it 'encrypt/decrypt should work' do
    t = Time.now
    travel_to(t)
    l = subject.generate_license('idxxx', 'pro')
    expect(l.length).to eql(512)
    expect(subject.decrypt(l)).to eql(['idxxx', 'pro', t.to_f.to_s, '0.0'])
    expect(subject.decrypt(l + 'a')).to eql(nil)
  end

  it 'encrypt should raise error if give invalid data' do
    expect {
      subject.generate_license('idxxx', 'asd')
    }.to raise_error("Invalid edition: asd")
  end

  it 'decrypt should return nil if give invalid data' do
    l = subject.generate_license('idxxx', 'pro')
    l[123] = 'a'
    expect(subject.decrypt(l)).to eql(nil)
  end

  it 'verify should return data if ex = 0' do
    t = Time.now
    travel_to(t)
    l = subject.generate_license('idxxx', 'pro')
    expect(l.length).to eql(512)
    expect(subject.verify(l)).to eql(['idxxx', 'pro', t.to_f.to_s, '0.0'])
  end

  it 'verify should return data according ex' do
    t = Time.now
    travel_to(t)
    l = subject.generate_license('idxxx', 'pro', expire_in: 10)
    expect(l.length).to eql(512)
    expect(subject.verify(l)).to eql(['idxxx', 'pro', t.to_f.to_s, (t.to_f + 10).to_s])
    travel_to(t + 11)
    expect(subject.verify(l)).to eql(nil)
  end
end
