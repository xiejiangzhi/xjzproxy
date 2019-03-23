RSpec.describe Xjz::IOHelper do
  describe '.read_nonblock' do
    let(:dst) { StringIO.new('') }

    it 'should copy stream' do
      rd, wr = IO.pipe
      wr << 'hello'
      data = ''
      save_proc = proc { |d| data << d }
      expect(subject.read_nonblock(rd, &save_proc)).to eql(true)
      expect(data).to eql('hello')

      wr << ' world'
      expect(subject.read_nonblock(rd, &save_proc)).to eql(true)
      expect(data).to eql('hello world')

      wr.close
      expect(subject.read_nonblock(rd, &save_proc)).to eql(false)
      expect(data).to eql('hello world')
    end
  end

  describe 'write_nonblock' do
    it 'should write all data' do
      data = 'hello world'
      rd, wr = IO.pipe
      subject.write_nonblock(wr, data)
      expect(rd.read_nonblock(100)).to eql('hello world')
      expect(data).to eql('')
    end

    it 'should write part data' do
      data = 'a' * 65540
      rd, wr = IO.pipe
      subject.write_nonblock(wr, data)
      expect(rd.read_nonblock(100000).length).to eql(65536)
      expect(data).to eql('a' * 4)
    end
  end

  describe '.forward_stream' do
    it 'should forward stream by hash mapping' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      r3, w3 = IO.pipe

      w1 << 'some data'
      Thread.new do
        sleep 0.1
        w1 << ' more data'
        sleep 0.1
        w1 << ' end data'
        w1.close
      end

      expect(subject.forward_streams(r1 => w2, r2 => w3)).to eql(true)
      expect(w2.closed?).to eql(true)
      expect(w3.closed?).to eql(true)
      expect(r3.read).to eql('some data more data end data')
    end

    it 'should timeout when too long have no data' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      sio = StringIO.new
      rw3 = Xjz::WriterIO.new(sio)
      w1 << 'a'

      expect(subject.forward_streams({ r1 => w2, r2 => rw3 }, timeout: 0.3)).to eql(false)
      expect(w2.closed?).to eql(false)
      expect(rw3.closed_write?).to eql(false)
      sio.rewind
      expect(sio.read).to eql('a')
    end

    it 'should stop if stop_wait_cb return true' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      sio = StringIO.new
      rw3 = Xjz::WriterIO.new sio
      w1 << 'a'
      Thread.new { sleep 0.1; w1 << 'b'; sleep 0.5; w1 << 'c' }

      expect(subject.forward_streams(
        { r1 => w2, r2 => rw3 },
        stop_wait_cb: proc { |st| Time.now - st > 0.2 }
      )).to eql(false)
      expect(w2.closed?).to eql(false)
      expect(rw3.closed_write?).to eql(false)
      sio.rewind
      expect(sio.read).to eql('ab')
    end

    it 'should forward stream and not wait' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      sio = StringIO.new
      rw3 = Xjz::WriterIO.new sio
      w1 << 'some data' << ' 1' << ' 2'
      w1.close

      t = Time.now
      expect(subject.forward_streams(r1 => w2, r2 => rw3)).to eql(true)
      expect(Time.now - t).to be < 0.01
      expect(w2.closed?).to eql(true)
      expect(rw3.closed_write?).to eql(true)
      sio.rewind
      expect(sio.read).to eql('some data 1 2')
    end
  end
end
