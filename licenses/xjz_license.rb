require 'openssl'

class XJZLicense
  attr_reader :pkey_path

  DIGEST = 'SHA256'
  KEY_SIZE = 1024 * 8
  FEATURE_FLAGS = %w{
    grpc diff req_res
  }

  def initialize(pkey_path)
    @pkey_path ||= pkey_path
  end

  def pkey
    @pkey ||= if File.exist?(pkey_path)
      OpenSSL::PKey::RSA.new(File.read(pkey_path))
    else
      OpenSSL::PKey::RSA.new(KEY_SIZE).tap do |key|
        File.write(pkey_path, key.to_pem)
        File.write(pkey_path + '.pub', key.public_key.to_pem)
      end
    end
  end

  def public_key
    @public_key ||= pkey.public_key
  end

  def generate_license(id, flags)
    pkey.private_encrypt(format_data(id, flags))
  end

  def decrypt(data)
    public_key.public_decrypt(data).split(',')
  rescue OpenSSL::PKey::RSAError
    nil
  end

  private

  def format_data(id, flags)
    flags.map!(&:to_s)
    eks = flags - (flags & FEATURE_FLAGS)
    raise "Invalid flags: #{eks.join(', ')}" unless eks.empty?
    ([id.to_s] + flags).join(',')
  end
end
