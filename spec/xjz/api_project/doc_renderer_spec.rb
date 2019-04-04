RSpec.describe Xjz::ApiProject::DocRenderer do
  describe '#render' do
    let(:ap) { $config['.api_projects'].first }
    let(:subject) { described_class.new(ap) }

    it 'should render with ap data' do
      expect(subject.render).to be_match(/asdf/)
    end
  end
end
