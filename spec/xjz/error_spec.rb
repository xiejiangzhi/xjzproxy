RSpec.describe 'Error' do
  it '#log_inspect should return exception info' do
    err = begin; asdf; rescue => e; e; end
    bts = err.backtrace.select { |bt| bt[$root] }
    expect(err.log_inspect).to eql("NameError #{err.message}: \n#{bts.join("\n")}")
  end
end
