RSpec.describe Xjz::ApiProject::GRPCParser do
  describe 'parse' do
    let(:dir) { File.expand_path('spec/files', $root) }
    let(:cache_path) { File.expand_path('.xjzapi/protos/protos.yml', dir) }

    before :each do
      FileUtils.rm_f(cache_path)
    end

    after :all do
      FileUtils.rm_f(File.join($root, 'spec/files/.xjzapi/protos/protos.yml'))
    end

    it 'should return grpc module' do
      subject = described_class.new(dir, 'dir' => './project_protobufs')
      gm = subject.parse
      expect(File.exist?(cache_path)).to eql(true)
      expect(gm).to be_a(Module)
      expect(gm.name).to be_match(/^Xjz::ApiProject::GRPCParser::ParsedModule_\w+/)
      expect(gm.pb_pool).to be_a(Google::Protobuf::DescriptorPool)
      expect(gm::Hw::Ms::Request.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw::Ms::Reply.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw::Greeter::Service.included_modules).to be_include(GRPC::GenericService)
      expect(gm::Hw2::Reply.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw2::Request.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect { Hw2::Reply }.to raise_error(NameError)
    end

    it 'should use protoc_args' do
      subject = described_class.new(dir, 'dir' => './project_protobufs', 'protoc_args' => '-xxx=asdf')
      %w{hello2.proto dir/messages.proto hello.proto}.each do |file|
        expect(subject).to receive(:generate_pbfiles).with(
          "bundle exec grpc_tools_ruby_protoc --ruby_out=#{File.join($root, 'spec/files/.xjzapi/protos')}" +
            " --grpc_out=#{$root}/spec/files/.xjzapi/protos" +
            " -I#{$root}/spec/files/project_protobufs -xxx=asdf",
          "#{$root}/spec/files/project_protobufs/#{file}").and_return([])
      end
      subject.parse
    end

    it 'should not regenerate protos if cache is valid' do
      subject = described_class.new(dir, 'dir' => './project_protobufs')
      subject.parse

      subject = described_class.new(dir, 'dir' => './project_protobufs')
      expect(subject).to_not receive(:generate_pbfiles)
      gm = subject.parse
      expect(File.exist?(cache_path)).to eql(true)
      expect(gm).to be_a(Module)
      expect(gm.pb_pool).to be_a(Google::Protobuf::DescriptorPool)
      expect(gm::Hw::Ms::Request.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw::Ms::Reply.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw::Greeter::Service.included_modules).to be_include(GRPC::GenericService)
      expect(gm::Hw2::Reply.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw2::Request.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect { Hw2::Reply }.to raise_error(NameError)
    end

    it 'should regenerate protos if cache is invalid' do
      subject = described_class.new(dir, 'dir' => './project_protobufs')
      subject.parse

      pb_path = subject.pb_cache.keys.last
      rb_pb_path = subject.pb_cache[pb_path].last.keys.first
      subject = described_class.new(dir, 'dir' => './project_protobufs')
      expect(subject).to receive(:generate_pbfiles) \
        .with(kind_of(String), pb_path).once.and_call_original
      File.open(rb_pb_path, 'a') { |f| f.write "\nraise 'asdf'" }
      gm = subject.parse
      expect(File.exist?(cache_path)).to eql(true)
      expect(gm).to be_a(Module)
      expect(gm.pb_pool).to be_a(Google::Protobuf::DescriptorPool)
      expect(gm::Hw::Ms::Request.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw::Ms::Reply.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw::Greeter::Service.included_modules).to be_include(GRPC::GenericService)
      expect(gm::Hw2::Reply.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw2::Request.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect { Hw2::Reply }.to raise_error(NameError)
    end
  end
end
