RSpec.describe Xjz::ThreadPool do
  let(:subject) { described_class.new(2, 1) }

  it 'should perform jobs with concurrent' do
    r = []
    # perform 0, 1, enqueue 2
    expect(3.times.map { |i| subject.post { sleep 0.1; r << i } }).to eql([true] * 3)
    sleep 0.02
    expect(subject.total_active_workers).to eql(2)
    sleep 0.1
    expect(r.length).to eql(2)
    expect(subject.total_active_workers).to eql(1)
    sleep 0.1
    expect(r.length).to eql(3)
    expect(r.last).to eql(2)
    expect(subject.workers.length).to eql(2)
    expect(subject.total_active_workers).to eql(0)
  end

  it 'should discard and return false if queue is full' do
    r = []
    # perform 0, 1, enqueue 2, discard 3
    expect(4.times.map { |i| subject.post { sleep 0.1; r << i } }).to eql([true] * 3 + [false])
    sleep 0.02
    expect(r.length).to eql(0)
    sleep 0.1
    expect(r.length).to eql(2)
    expect(subject.total_active_workers).to eql(1)
    sleep 0.1
    expect(r.length).to eql(3)
    expect(r.last).to eql(2)
    expect(subject.workers.length).to eql(2)
    expect(subject.total_active_workers).to eql(0)
  end

  it 'should discard job when max queue size is zero' do
    pool = described_class.new(2)
    r = []
    expect(3.times.map { |i| pool.post { sleep 0.1; r << i } }).to eql([true] * 2 + [false])
    sleep 0.02
    expect(r.length).to eql(0)
    sleep 0.1
    expect(r.length).to eql(2)
    sleep 0.1
    expect(r.length).to eql(2)
  end

  it 'should post with args' do
    r = []
    subject.post(1, 2) { |a, b| r << a << b }
    sleep 0.02
    expect(r).to eql([1, 2])
  end

  it 'should auto stop threads when timeout' do
    2.times { subject.post { 0 } }
    sleep 0.12
    expect(subject.workers.count(&:alive?)).to eql(2)
    expect(subject.total_active_workers).to eql(0)

    stub_const('Xjz::ThreadPool::THREAD_TIMEOUT', 0.1)
    sleep 0.12
    expect(subject.workers.count(&:alive?)).to eql(0)
    expect(subject.workers.length).to eql(2) # just kill, clean in next post

    subject.post { 1 }
    expect(subject.workers.count(&:alive?)).to eql(1)
    expect(subject.workers.length).to eql(1) # clean and start one
  end

  it 'kill should kill all workers and clear queue' do
    r = []
    3.times { |i| subject.post { sleep 0.1; r << i } }
    expect {
      subject.kill
    }.to change { subject.workers }.to([])
    sleep 0.12
    expect(r).to eql([])
    subject.post { r << 1 }
    sleep 0.12
    expect(r).to eql([1])
  end

  it 'shutdown should kill all workers and cannot enqueue new job' do
    r = []
    2.times { |i| subject.post { sleep 0.1; r << i } }
    expect {
      subject.shutdown
    }.to change { subject.workers }.to([])
    sleep 0.12
    expect(r).to eql([])
    expect {
      subject.post { r << 1 }
    }.to raise_error("Pool was shutdown")
    sleep 0.01
    expect(r).to eql([])
  end
end
