require 'base64'
require 'rack'
require 'json'
require 'logger'

require 'bloomfilter-rb'

require_relative './xjz_license'

class LicenseWebapp
  BF_SIZE = 1024 * 1024 * 20
  EXPIRES = 3600 * 24 * 7

  BFS_SIZE = {
    license: BF_SIZE,
    uid: BF_SIZE,
    change: 1024 * 32 # allow little user to change computer
  }

  ALL_RES = {
    valid: [ 200, {}, [{ valid: true }.to_json]],
    invalid_license: [ 200, {}, [{ valid: false, msg: "Invalid license" }.to_json]],
    invalid_pc: [ 200, {}, [{ valid: false, msg: 'Cannot be used on multiple computers' }.to_json]],
    not_found: [404, {}, [{ msg: 'Not Found' }.to_json]],
    invalid_params: [400, {}, [{ msg: 'Invalid params' }.to_json]]
  }

  LICENSE_PATH = File.expand_path('../license_key', __FILE__)

  attr_reader :logger

  def initialize
    @bfs = {}
    @license_manager = XJZLicense.new(LICENSE_PATH)
    @logger = Logger.new($stdout)
  end

  def call(env)
    req = Rack::Request.new(env)
    req.env['xjz.log'] = [req.ip]

    if req.path == '/v'
      r = verify(req)
      r ? r : fetch_res(:invalid_params)
    else
      fetch_res :not_found
    end
  rescue => e
    @Logger.error e.message
    @Logger.error e.backtrace.join("\n")
    env['xjz.log'] << 'err'
    fetch_res :invalid_params
  ensure
    @logger.info env['xjz.log'].inspect unless env['xjz.log'].empty?
  end

  def verify(req)
    l, uid = req.params.values_at(*%w{l id})
    req.env['xjz.log'] << uid if uid
    l = Base64.strict_decode64(l || '') rescue nil
    return fetch_res(:invalid_params) unless l && uid
    data = @license_manager.verify(l)
    return fetch_res(:invalid_license) if data.nil? || data.empty?

    lid = data.join(', ')
    req.env['xjz.log'] << lid
    lbf = fetch_bf :license
    ubf = fetch_bf :uid
    lcbf = fetch_bf(:change)

    if lbf.include?(lid)
      if ubf.include?(uid)
        req.env['xjz.log'] << 'ok retry'
        fetch_res :valid
      elsif lcbf.include?(lid)
        # has change history, cannot change again
        req.env['xjz.log'] << 'dup'
        fetch_res :invalid_pc
      else
        ubf.insert(uid) # register this uid
        lcbf.insert(lid) # add change history
        req.env['xjz.log'] << 'ok change'
        fetch_res :valid
      end
    else
      ubf.insert(uid)
      lbf.insert(lid)
      req.env['xjz.log'] << 'ok new'
      fetch_res :valid
    end
  end

  private

  def fetch_res(id)
    r = ALL_RES[id]
    return r if r
    raise "Not found res by #{id.inspect}"
  end

  def fetch_bf(bf_id)
    bf_id = bf_id.to_s.to_sym
    bf, ts = @bfs[bf_id]
    return bf if ts && Time.now < ts
    size = BFS_SIZE[bf_id]
    raise "Undefined bf size #{bf_id.inspect}" unless size
    (@bfs[bf_id] = [new_bf(size), Time.now + EXPIRES]).first
  end

  def new_bf(size)
    BloomFilter::Native.new(
      size: size,
      hashes: 3,
      bucket: 1,
      raise: false
    )
  end
end
