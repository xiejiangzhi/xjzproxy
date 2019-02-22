require 'openssl'

class CertGen
  def initialize
    @ca_path = File.join($root, $config['root_ca_path'])
    @key_path = File.join($root, $config['key_path'])
  end

  def pkey
    @pkey ||= if File.exists?(@key_path)
      OpenSSL::PKey::RSA.new File.read(@key_path)
    else
      OpenSSL::PKey::RSA.new(2048).tap { |key| File.write(@key_path, key.to_pem) }
    end
  end

  def root_ca
    return @root_ca if @root_ca

    @root_ca = OpenSSL::X509::Certificate.new(File.read(@ca_path)) if File.exists?(@ca_path)
    @root_ca ||= begin
      cert = create_cert(pkey, $app_name) do |c, ef|
        c.serial = 0
        c.issuer = c.subject # root CA's are 'self-signed'

        ef.subject_certificate = c
        ef.issuer_certificate = c
        c.add_extension(ef.create_extension("basicConstraints", "CA:TRUE", true))
        c.add_extension(ef.create_extension("keyUsage", "keyCertSign, cRLSign", true))
        c.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
        c.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always", false))
        c.add_extension(ef.create_extension("nsComment", "#{$app_name} Generated Certificate"))
      end

      File.write(@ca_path, cert.to_pem)
      cert
    end
  end

  def issue_cert(hostname)
    create_cert(pkey, hostname) do |c, ef|
      c.issuer = root_ca.subject # sign by root ca
      ef.subject_certificate = c
      ef.issuer_certificate = root_ca
      c.add_extension(ef.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
      c.add_extension(ef.create_extension("extendedKeyUsage", 'serverAuth,clientAuth', false))
      c.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
      c.add_extension(ef.create_extension("basicConstraints", "CA:false", false))
      c.add_extension(ef.create_extension("subjectAltName", "DNS: #{hostname}", false))
    end
  end

  private

  def create_cert(key, cn, &other_config)
    OpenSSL::X509::Certificate.new.tap do |cert|
      cert.version = 2 # cf. RFC 5280 - to make it a "v3" certificate
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.parse("/CN=#{cn}/O=#{$app_name}")
      cert.public_key = key.public_key
      cert.not_before = Time.now
      cert.not_after = Time.now + 1.year
      ef = OpenSSL::X509::ExtensionFactory.new
      other_config.call(cert, ef) if other_config
      cert.sign(key, OpenSSL::Digest::SHA256.new)
    end
  end
end
