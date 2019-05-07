RSpec.describe Xjz::ParamsDiff do
  let(:types) { Xjz::ApiProject::DataType.default_types }

  describe '#diff' do
    it 'should return diff data for simple data' do
      expect(
        subject.diff({ a: 1, b: 2, c: types['integer'] }, a: 2, b: 2, c: 123)
      ).to eql([["Hash[:a]", 1, 2]])

      expect(
        subject.diff([1, '2', types['integer'], 4], [1, 2, '123', 5])
      ).to eql([
        ["Array[1]", '2', 2],
        ["Array[2]", types['integer'], "123"],
        ["Array[3]", 4, 5]
      ])

      expect(
        subject.diff('a', 'b')
      ).to eql([['String', 'a', 'b']])

      expect(
        subject.diff([1, 2], [1, 2, 3])
      ).to eql([['Array[2]', nil, 3]])

      expect(
        subject.diff([1, types['integer'], 3], [1, 2, 3])
      ).to eql([])
    end

    it 'should return diff data for complex data' do
      expect(
        subject.diff(
          {
            a: [3, types['integer'], { a: 1, b: 3 }, [ 99, 66 ]],
            b: { a: [1, 2], b: { d: types['string'] } },
            c: [1, 2],
            d: { a: 1 }
          },
          a: [3, 123, { a: 2, b: 3 }, [ 66, 66 ]],
          b: { a: [1, '2'], b: { d: '123', e: 'nn' } }
        )
      ).to eql([
        ["Hash[:a][2][:a]", 1, 2],
        ["Hash[:a][3][0]", 99, 66],
        ["Hash[:b][:a][1]", 2, "2"],
        ["Hash[:b][:b][:e]", nil, "nn"],
        ["Hash[:c]", [1, 2], nil],
        ["Hash[:d]", { a: 1 }, nil]
      ])
    end

    it 'should ignore key if start with .' do
      expect(
        subject.diff(
          {
            a: [types['integer'], { '.a.desc' => 'xxx', a: 1 }],
            b: { a: 1, '.c' => 'xxx' },
            '.b' => 'xxx'
          },
          a: [3, { a: 1, b: 3 }],
          b: { a: 1, '.c' => 'yyy' }
        )
      ).to eql([
        ["Hash[:a][1][:b]", nil, 3],
        ["Hash[:b][\".c\"]", 'xxx', 'yyy']
      ])
    end

    it 'should allow extend data if it is true' do
      subject = described_class.new(allow_extend: true)
      expect(
        subject.diff(
          { a: [1, 2], c: [1], d: { v: 2 } },
          a: [1, 2, 3],
          b: 321,
          c: []
        )
      ).to eql([
        ["Hash[:c][0]", 1, nil],
        ["Hash[:d]", { v: 2 }, nil]
      ])
    end
  end
end
