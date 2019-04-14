RSpec.describe Xjz::ApiProject::GRPC do
  let(:ap) { Xjz::ApiProject.new(File.join($root, 'spec/files/grpc.yml')) }
  let(:subject) { Xjz::ApiProject::GRPC.new(ap) }

  describe 'find_rpc' do
    it 'should return a rpc object' do
      rpc = subject.find_rpc('/Hw.Greeter/SayHello')
      expect(rpc).to be_a(GRPC::RpcDesc)
      expect(rpc.input).to eql(subject.grpc::Hw::Ms::Request)
      expect(rpc.output).to eql(subject.grpc::Hw::Ms::Reply)
    end

    it 'should return nil when not found rpc' do
      expect(subject.find_rpc('/Hw.Greeter123/SayHello')).to be_nil
      expect(subject.find_rpc('/Hw.Greeter/SayHello321')).to be_nil
    end
  end

  describe 'input_desc/output_desc' do
    it 'should return input desc' do
      expect(subject.input_desc('/Hw.Greeter/SayHello')).to eql(
        "name" => ap.data['types']['string']
      )
    end

    it 'should return output desc' do
      types = ap.data['types']
      desc = subject.output_desc('/Hw.Greeter/SayHello')
      expect(desc.delete('type')).to be_between(0, 1)
      expect(desc).to eql(
        "aa" => types['string'],
        "bb" => types['string'],
        "info" => { "age" => types['integer'] },
        "keywords" => [types['string']],
        "message" => types['string']
      )
    end

    it 'should return nil for invalid path' do
      expect(subject.input_desc('/Hw.Greeter/SayHello1')).to be_nil
    end
  end

  describe 'res_desc' do
    it 'should return a response of api desc' do
      expect(subject.res_desc('/Hw.Greeter/SayHello')).to eql(
        'data' => {
          "aa" => "data a",
          "bb" => "data b",
          "info" => { "age" => 23 },
          "keywords" => ["a", "b"],
          "message" => "hello gRPC"
        },
        'headers' => { "a" => "aaa" },
        'http_code' => 400
      )
    end

    it 'should return a response of output desc if has no api desc' do
      types = ap.data['types']
      res = subject.res_desc('/Hw.Greeter/SayName')
      expect(res['data'].delete('type')).to be_between(0, 1)
      expect(res).to eql(
        'data' => {
          "aa" => types['string'],
          "bb" => types['string'],
          "info" => { "age" => types['integer'] },
          "keywords" => [types['string']],
          "message" => types['string']
        },
        'headers' => {},
        'http_code' => 200
      )
    end

    it 'should return nil if api is disabled' do
      om = ap.method(:find_api)
      allow(ap).to receive(:find_api) do |*args|
        expect(args).to eql(['post', nil, nil, '/Hw.Greeter/SayHello'])
        om.call(*args).merge('enabled' => false)
      end
      expect(subject.res_desc('/Hw.Greeter/SayHello')).to be_nil
    end

    it 'should return nil if not found rpc api' do
      expect(subject.res_desc('/Hw.Greeter/SayHelloasdf')).to be_nil
    end
  end

  describe '#services' do
    it 'should return all services' do
      t = Time.now
      allow(Time).to receive(:now).and_return(t)
      id = "ffed6c4896a5fb9483521dc8b0fd3dea759abcc74371e801ee66fde2d323c6fe_#{t.to_f}".tr('.', '')
      expect(subject.services.map(&:name)).to eql([
        "Xjz::ApiProject::GRPCParser::ParsedModule_#{id}::Hw::Greeter::Service"
      ])

      m = Class.new { include GRPC::GenericService }
      subject.grpc.const_set("GxxxxService", m)
      expect(subject.services.map(&:name).sort).to eql([
        "Xjz::ApiProject::GRPCParser::ParsedModule_#{id}::Hw::Greeter::Service",
        "Xjz::ApiProject::GRPCParser::ParsedModule_#{id}::GxxxxService"
      ].sort)
    end
  end

  describe '#proto_msg_to_schema' do
    it 'should return a scheme' do
      expect(subject.proto_msg_to_schema(subject.grpc::Hw::Ms::Request)).to eql(
        "name" => ap.data['types']['string']
      )
    end

    it 'should raise a error for invalid msg' do
      expect {
        expect(subject.proto_msg_to_schema('asdf'))
      }.to raise_error("Invalid proto msg, it isn't a protobuf message")

      expect {
        expect(subject.proto_msg_to_schema(Class.new))
      }.to raise_error("Invalid proto msg, it isn't a protobuf message")
    end
  end
end
