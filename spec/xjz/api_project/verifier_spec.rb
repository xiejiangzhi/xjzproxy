RSpec.describe Xjz::ApiProject::Verifier do
  let(:file_path) { File.join($root, 'spec/files/project.yml') }
  let(:raw_data) { Xjz::ApiProject.new(file_path).raw_data }

  describe 'verify' do
    it 'should return nil if has no error' do
      expect(subject.verify(raw_data)).to eql(nil)
    end

    it 'should return nil if has undefined keys' do
      d = raw_data.deep_dup
      d['asdf'] = 'lkajsdf'
      d['types']['avatar']['lkjalksdf'] = 123
      d['apis'][0]['lkjalksdf'] = 123
      d['project']['asdf'] = '12313'
      d['responses']['show_user']['asdf'] = '12313'
      d['plugins'][0]['asdf'] = '12313'
      expect(subject.verify(raw_data)).to eql(nil)
    end

    it 'should return errors if has some bad format' do
      d = raw_data.deep_dup
      d['types']['xxx'] = { 'items' => 1 }
      d['partials']['xxx'] = 123
      d['apis'] << { a: 1 }
      d['responses']['123'] = { b: 2 }
      d['plugins'] << { b: 2 }
      expect(subject.verify(d)).to eql([
        { full_path: "Hash[\"responses\"][\"123\"][\"http_code\"]", message: "present" },
        { full_path: "Hash[\"responses\"][\"123\"][\"data\"]", message: "present" },
        { full_path: "Hash[\"types\"][\"xxx\"][\"items\"]", message: "a/an NilClass" },
        { full_path: "Hash[\"types\"][\"xxx\"][\"items\"]", message: "a/an Array" },
        {
          full_path: "Hash[\"types\"][\"xxx\"][\"items\"]",
          message: "one of absent (marked as :optional), a/an NilClass, a/an Array"
        },
        { full_path: "Hash[\"plugins\"][3][\"title\"]", message: "present" },
        { full_path: "Hash[\"plugins\"][3][\"labels\"]", message: "present" },
        { full_path: "Hash[\"apis\"][2][\"title\"]", message: "present" },
        { full_path: "Hash[\"apis\"][2][\"method\"]", message: "present" },
        { full_path: "Hash[\"apis\"][2][\"path\"]", message: "present" },
        { full_path: "Hash[\"apis\"][2][\"response\"]", message: "present" }
      ])
    end
  end
end
