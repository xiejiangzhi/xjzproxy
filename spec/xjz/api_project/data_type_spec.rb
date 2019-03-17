RSpec.describe Xjz::ApiProject::DataType do
  describe 'generate' do
    it 'should return data by items' do
      subject = described_class.new('items' => 123)
      expect(subject.generate).to eql(123)
      expect(subject.generate).to eql(123)
    end

    it 'should return data by items array' do
      vals = [123, 'asdf']
      subject = described_class.new('items' => vals)
      5.times.map { expect(vals.include?(subject.generate)).to eql(true) }
    end

    it 'should return data by items and prefix' do
      subject = described_class.new('items' => 123, 'prefix' => 666)
      expect(subject.generate).to eql('666123')
    end

    it 'should return data by items and suffix' do
      subject = described_class.new('items' => 123, 'suffix' => 666)
      expect(subject.generate).to eql('123666')
    end

    it 'should return data by items array and prefix + suffix' do
      subject = described_class.new(
        'items' => [123, '---'], 'prefix' => ['a', 'aa'], 'suffix' => ['b', 'bb']
      )
      5.times.map { expect(subject.generate).to be_match(/^aa?(123|---)bb?$/) }
    end

    it 'should replace i variable' do
      subject = described_class.new(
        'items' => ['-%{i}-'], 'prefix' => 'a%{i}a', 'suffix' => ['b%{i}b']
      )
      expect(subject.generate).to eql('a1a-1-b1b')
      expect(subject.generate).to eql('a2a-2-b2b')

      s2 = described_class.new(
        'items' => ['-%{i}-'], 'prefix' => 'a%{i}a', 'suffix' => ['b%{i}b']
      )
      expect(s2.generate).to eql('a1a-1-b1b')

      expect(subject.generate).to eql('a3a-3-b3b')
    end
  end
end
