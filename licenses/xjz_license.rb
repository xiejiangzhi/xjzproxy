require 'openssl'

class XJZLicense
  attr_reader :pkey_path

  DIGEST = 'SHA256'
  KEY_SIZE = 1024 * 8
  EDITIONS = %w{trial standard pro}
  FLAGS = %w{}

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

  def generate_license(id, edition, expire_at: nil, expire_in: nil, flags: nil)
    expire_at ||= Time.now + expire_in.to_i if expire_in
    encrypt(gen_data(id, edition, expire_at: expire_at, flags: flags))
  end

  def encrypt(str)
    pkey.private_encrypt(str)
  end

  def decrypt(data)
    public_key.public_decrypt(data).split(',')
  rescue OpenSSL::PKey::RSAError
    nil
  end

  private

  def gen_data(id, edition, flags: nil, expire_at: nil)
    flags ||= []
    flags.map!(&:to_s)
    eks = flags - (flags & FLAGS)
    raise "Invalid flags: #{eks.join(', ')}" unless eks.empty?
    edition = edition.to_s.downcase
    raise "Invalid edition: #{edition}" unless EDITIONS.include?(edition)
    ([id.to_s, edition, Time.now.to_f.to_s, expire_at.to_f.to_s] + flags).join(',')
  end
end
