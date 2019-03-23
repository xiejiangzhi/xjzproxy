RSpec.describe 'Error' do
  it '#log_inspect should return exception info' do
    err = begin; asdf; rescue => e; e; end
    expect(err.log_inspect).to eql("NameError #{err.message}: \n#{err.backtrace.join("\n")}")
  end
end
