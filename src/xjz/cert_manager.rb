require 'openssl'
require 'fileutils'

module Xjz
  class CertManager
    CA_FNAME = 'root_ca.pem'
    KEY_FNAME = 'key.pem'

    def initialize
      @key = nil
      @root_ca = nil
    end

    def pkey
      @pkey ||= if key = $config.read_user_file(KEY_FNAME)
        OpenSSL::PKey::RSA.new key
      else
        OpenSSL::PKey::RSA.new(2048).tap { |key| $config.write_user_file(KEY_FNAME, key.to_pem) }
      end
    end

    def pkey_fingerprint
      gen_fingerprint(pkey.to_der)
    end

    def reset!
      $config.clean_user_file(CA_FNAME)
      $config.clean_user_file(KEY_FNAME)
      @pkey = nil
      @root_ca = nil
    end

    def root_ca
      return @root_ca if @root_ca

      ca = $config.read_user_file(CA_FNAME)
      @root_ca = OpenSSL::X509::Certificate.new(ca) if ca
      @root_ca ||= begin
        cert = create_cert(pkey, $app_name) do |c, ef|
          c.serial = 1
          c.issuer = c.subject # root CA's are 'self-signed'
          c.not_after = Time.now + 99.year

          ef.subject_certificate = c
          ef.issuer_certificate = c
          c.add_extension(ef.create_extension("basicConstraints", "CA:TRUE", true))
          c.add_extension(ef.create_extension("keyUsage", "keyCertSign, cRLSign", true))
          c.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
          c.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always", false))
          c.add_extension(ef.create_extension("nsComment", "#{$app_name} Generated Certificate"))
        end

        $config.write_user_file(CA_FNAME, cert.to_pem)
        cert
      end
    end

    def root_ca_fingerprint
      gen_fingerprint(root_ca.to_der)
    end

    def issue_cert(hostname)
      create_cert(pkey, hostname) do |c, ef|
        c.issuer = root_ca.subject # sign by root ca
        ef.subject_certificate = c
        ef.issuer_certificate = root_ca
        c.add_extension(ef.create_extension("basicConstraints", "CA:false", true))
        c.add_extension(ef.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
        c.add_extension(ef.create_extension("extendedKeyUsage", 'serverAuth,clientAuth', false))
        c.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
        c.add_extension(ef.create_extension("subjectAltName", "DNS: #{hostname}", false))
      end
    end

    private

    def create_cert(key, cn, &other_config)
      OpenSSL::X509::Certificate.new.tap do |cert|
        cert.version = 2 # cf. RFC 5280 - to make it a "v3" certificate
        cert.serial = (Time.now.to_f * 10000000).to_i
        cert.subject = OpenSSL::X509::Name.parse("/CN=#{cn}/O=#{$app_name}")
        cert.public_key = key.public_key
        cert.not_before = Time.now
        cert.not_after = Time.now + 1.year
        ef = OpenSSL::X509::ExtensionFactory.new
        other_config.call(cert, ef) if other_config
        cert.sign(key, OpenSSL::Digest::SHA256.new)
      end
    end

    def gen_fingerprint(der_str)
      OpenSSL::Digest::SHA1.hexdigest(der_str).scan(/../).join(':')
    end
  end
end
