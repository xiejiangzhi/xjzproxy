RSpec.describe Xjz::ApiProject::DataType do
  let(:types) { described_class.default_types }

  describe '#generate' do
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

    it 'should generate for default types' do
      subject = types['integer']
      expect(subject.generate).to be_a(Integer)

      subject = types['name']
      expect(subject.generate).to be_a(String)
    end

    it 'should generate by regexp' do
      regexp_str = '://xjz\.pw/[\w-]*'
      subject = described_class.new('regexp' => regexp_str, 'prefix' => 'https')
      regexp = Regexp.new(regexp_str)
      r = 5.times.map { subject.generate }.uniq
      expect(r).to_not eql(1)
      r.each { |v| expect(v).to be_match(regexp) }
      expect(r.first[0..4]).to eql('https')
    end
  end

  describe '#verify' do
    it 'should verify by val class' do
      expect(types['integer'].verify(123)).to eql(true)
      expect(types['integer'].verify('123')).to eql(false)
      expect(types['string'].verify(123)).to eql(false)
      expect(types['string'].verify('222')).to eql(true)
      expect(types['boolean'].verify(true)).to eql(true)
      expect(types['boolean'].verify(false)).to eql(true)
      expect(types['color_name'].verify('#xxx')).to eql(true)
      expect(types['color_name'].verify('yyy')).to eql(true)
    end

    it 'should verify by proc' do
      subject = described_class.new('items' => 123, 'validator' => proc { |v| v > 3 rescue false })
      expect(subject.verify(3)).to eql(false)
      expect(subject.verify(4)).to eql(true)
      expect(subject.verify('4')).to eql(false)
    end

    it 'should verify by regexp' do
      subject = described_class.new('regexp' => 'go+d$')
      expect(subject.verify('god')).to eql(true)
      expect(subject.verify('good')).to eql(true)
      expect(subject.verify('goood')).to eql(true)
      expect(subject.verify('123god')).to eql(true)
      expect(subject.verify('goaod')).to eql(false)
      expect(subject.verify('god123')).to eql(false)
    end
  end

  describe 'other' do
    it 'should allow redefine default type' do
      subject = described_class.new('type' => 'integer', 'items' => [1, 2, 3])
      5.times { expect(subject.generate).to be_between(1, 3) }
    end
  end
end
