RSpec.describe Xjz::ParamsDiff do
  let(:types) { Xjz::ApiProject::DataType.default_types }

  describe '#diff' do
    it 'should return diff data for simple data' do
      expect(
        subject.diff({ a: 1, b: 2, c: types['integer'] }, a: 2, b: 2, c: 123)
      ).to eql([["Hash[:a]", 1, 2]])

      expect(
        subject.diff([1, '2', types['integer']], [1, 2, '123'])
      ).to eql([["Array[1]", '2', 2],  ["Array[2]", types['integer'], "123"]])

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
            b: { a: [1, 2], b: { d: types['string'] } }
          },
          a: [3, 123, { a: 2, b: 3 }, [ 66, 66 ]],
          b: { a: [1, '2'], b: { d: '123', e: 'nn' } }
        )
      ).to eql([
        ["Hash[:a][2][:a]", 1, 2],
        ["Hash[:a][3][0]", 99, 66],
        ["Hash[:b][:a][1]", 2, "2"],
        ["Hash[:b][:b][:e]", nil, "nn"]
      ])
    end
  end
end
