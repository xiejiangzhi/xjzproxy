RSpec.describe Xjz::CertManager do
  describe '#pkey' do
    before :each do
      FileUtils.rm_rf(File.join($root, $config['key_path']))
    end

    it 'should return RSA private key' do
      expect(subject.pkey).to be_a(OpenSSL::PKey::RSA)
      expect(subject.pkey.object_id).to eql(subject.pkey.object_id)
      expect(subject.pkey_fingerprint).to match(/^\w{2}(:\w{2})+$/)
    end

    it 'should read key from file if key file is existed' do
      cg1 = Xjz::CertManager.new
      cg2 = Xjz::CertManager.new
      expect(cg1.pkey.to_pem).to eql(cg2.pkey.to_pem)
      key = OpenSSL::PKey::RSA.new(2048)
      File.write($config['key_path'], key.to_pem)
      cg3 = Xjz::CertManager.new
      expect(cg3.pkey.to_pem).to_not eql(cg2.pkey.to_pem)
      expect(cg3.pkey.to_pem).to eql(key.to_pem)
    end
  end

  describe '#root_ca' do
    before :each do
      FileUtils.rm_rf(File.join($root, $config['root_ca_path']))
    end

    it 'should create root ca' do
      ca = subject.root_ca
      pkey = subject.pkey
      expect(File.read($config['root_ca_path'])).to eql(ca.to_pem)

      expect(ca.serial.to_i).to eql(1)
      expect(ca.version).to eql(2)
      expect(ca.subject.to_a).to eql([["CN", $app_name, 12], ["O", "XjzProxy", 12]])
      expect(ca.public_key.to_pem).to eql(pkey.public_key.to_pem)
      expect(ca.not_before <= Time.now).to eql(true)
      expect(ca.not_after >= (Time.now + 1.year - 1)).to eql(true)
      expect(ca.signature_algorithm).to eql('sha256WithRSAEncryption')
      expect(ca.check_private_key(pkey)).to eql(true)
      seq = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Integer.new(pkey.n), OpenSSL::ASN1::Integer.new(pkey.e)
      ])
      key_id = OpenSSL::Digest::SHA1.hexdigest(seq.to_der).upcase.scan(/../).join(':')
      expect(ca.extensions.map(&:to_a)).to eql([
        ["basicConstraints", "CA:TRUE", true],
        ["keyUsage", "Certificate Sign, CRL Sign", true],
        ["subjectKeyIdentifier", key_id, false],
        ["authorityKeyIdentifier", "keyid:#{key_id}\n", false],
        ["nsComment", "XjzProxy Generated Certificate", false]
      ])
      expect(subject.root_ca_fingerprint).to match(/^\w{2}(:\w{2})+$/)
    end

    it 'should read root_ca from file if it is existed' do
      pkey = subject.pkey
      ca = subject.root_ca
      old_pem = ca.to_pem
      ca.subject = OpenSSL::X509::Name.parse("/CN=asdf/O=asdf")
      ca.sign(pkey, OpenSSL::Digest::SHA256.new)
      expect(ca.to_pem).to_not eql(old_pem)
      File.write($config['root_ca_path'], ca.to_pem)

      new_ca = Xjz::CertManager.new.root_ca
      expect(new_ca.to_pem).to eql(ca.to_pem)
    end
  end

  describe '#issue_cert' do
    it 'should return a new cert of a hostname' do
      pkey = subject.pkey
      ca = subject.issue_cert('xjz.pw')

      expect(ca.serial.to_i > Time.now.to_f).to eql(true)
      expect(ca.version).to eql(2)
      expect(ca.subject.to_a).to eql([["CN", 'xjz.pw', 12], ["O", $app_name, 12]])
      expect(ca.public_key.to_pem).to eql(pkey.public_key.to_pem)
      expect(ca.not_before <= Time.now).to eql(true)
      expect(ca.not_after >= (Time.now + 1.year - 1)).to eql(true)
      expect(ca.signature_algorithm).to eql('sha256WithRSAEncryption')
      expect(ca.check_private_key(pkey)).to eql(true)
      seq = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Integer.new(pkey.n), OpenSSL::ASN1::Integer.new(pkey.e)
      ])
      key_id = OpenSSL::Digest::SHA1.hexdigest(seq.to_der).upcase.scan(/../).join(':')
      expect(ca.extensions.map(&:to_a)).to eql([
        ["basicConstraints", "CA:FALSE", true],
        ["keyUsage", "Digital Signature, Key Encipherment", true],
        ["extendedKeyUsage", "TLS Web Server Authentication, TLS Web Client Authentication", false],
        ["subjectKeyIdentifier", key_id, false],
        ["subjectAltName", "DNS:xjz.pw", false]
      ])
    end
  end
end
