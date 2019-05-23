load File.join($root, 'licenses/license_webapp.rb')

RSpec.describe LicenseWebapp do
  let(:sock) { double('sock') }
  let(:license) { File.read(Xjz::Config::LICENSE_PATH) }
  let(:uid) { 'xxx' }
  let(:env) do
    {
      "SCRIPT_NAME" => "",
      "QUERY_STRING" => "",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "REQUEST_METHOD" => "POST",
      "REQUEST_URI" => "http://l.xjz.pw/v",
      "HTTP_HOST" => "l.xjz.pw",
      "HTTP_USER_AGENT" => "curl/7.54.0",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_CONTENT_TYPE" => "text/plain; charset=utf-8",
      "HTTP_CONNECTION" => "keep-alive",
      "SERVER_NAME" => "l.xjz.pw",
      "SERVER_PORT" => "80",
      "REQUEST_PATH" => "/v",
      "PATH_INFO" => "/v",
      "REMOTE_ADDR" => "127.0.0.1",
      "rack.hijack?" => true,
      "rack.hijack" => proc { sock },
      "rack.hijack_io" => sock,
      "rack.input" => new_params_input(license, uid),
      "rack.url_scheme" => "http"
    }
  end

  def new_params_input(l, id)
    StringIO.new({ l: Base64.strict_encode64(l), id: id }.to_query)
  end

  before :each do
    subject.logger.reopen('/dev/null')
  end

  it 'should return valid: true' do
    expect(subject.call(env)).to eql([200, {}, [{ valid: true }.to_json]])
  end

  it 'should return 400 for invalid params' do
    env['rack.input'] = StringIO.new('a=1')
    expect(subject.call(env)).to eql([400, {}, [{ msg: 'Invalid params' }.to_json]])
  end

  it 'should return 400 for invalid license' do
    env['rack.input'] = new_params_input('a', 'b')
    expect(subject.call(env)).to eql([200, {}, [{ valid: false, msg: 'Invalid license' }.to_json]])
  end

  it 'should return valid: true for duplicate request' do
    e2 = env.dup
    expect(subject.call(env)).to eql([200, {}, [{ valid: true }.to_json]])
    e2['rack.input'] = new_params_input(license, uid)
    expect(subject.call(e2)).to eql([200, {}, [{ valid: true }.to_json]])
  end

  it 'should return valid: false for duplicate licesen, but differnt uid ' do
    expect(subject.call(env.dup)).to eql([200, {}, [{ valid: true }.to_json]])

    # allow change once
    e2 = env.dup
    e2['rack.input'] = new_params_input(license, 'yyy')
    expect(subject.call(e2)).to eql([200, {}, [{ valid: true }.to_json]])

    e3 = env.dup
    e3['rack.input'] = new_params_input(license, 'zzz')
    expect(subject.call(e3)).to eql([
      200, {}, [{ valid: false, msg: "Cannot be used on multiple computers" }.to_json]
    ])
  end

  it 'should return valid: true again in next tiem circle' do
    expect(subject.call(env.dup)).to eql([200, {}, [{ valid: true }.to_json]])

    # next circle
    t = Time.now
    allow(Time).to receive(:now).and_return(t + 7.day + 1)
    e2 = env.dup
    e2['rack.input'] = new_params_input(license, 'yyy')
    expect(subject.call(e2)).to eql([200, {}, [{ valid: true }.to_json]])

    # same circle first change, allowed
    e3 = env.dup
    e3['rack.input'] = new_params_input(license, 'zzz')
    expect(subject.call(e3)).to eql([200, {}, [{ valid: true }.to_json]])

    # same circle change again, reject
    e4 = env.dup
    e4['rack.input'] = new_params_input(license, 'nnn')
    expect(subject.call(e4)).to eql([
      200, {}, [{ valid: false, msg: "Cannot be used on multiple computers" }.to_json]
    ])
  end
end
