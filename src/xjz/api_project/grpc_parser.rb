require 'open3'
require 'fileutils'
require 'shellwords'
require 'google/protobuf'

module Xjz
  class ApiProject::GRPCParser
    attr_reader :root_path, :options, :protos_path, :output_path, :grpc_module
    attr_reader :pb_cache

    PROTOC_CMD = 'bundle exec grpc_tools_ruby_protoc' +
      " --ruby_out=%{out_path} --grpc_out=%{out_path} -I%{lib_path}"

    CACHE_FILENAME = 'protos.yml'

    # options:
    #   dir:
    #   protoc_args:
    #   proto_files: [array of c glob string] which file will load. default ['**/*.proto']
    #     Ref https://ruby-doc.org/core-2.2.0/Dir.html#method-c-glob
    def initialize(path, options)
      @root_path = path
      @options = options
      options['dir'] ||= './protos'
      options['proto_files'] ||= ['**/*.proto']

      @protos_path = File.expand_path(options['dir'], root_path)
      @output_path = File.expand_path('.xjzapi/protos', root_path)
      FileUtils.mkdir_p(@output_path)
      @grpc_module = nil
      @pb_cache = load_cache_data || {}
    end

    def parse
      return grpc_module if grpc_module

      unless File.directory?(protos_path)
        Logger[:auto].error { "Not found gRPC folder #{protos_path}" }
        return
      end

      files = generate_rb_files
      save_cache_data!
      @grpc_module = load_protos(files)
    end

    private

    def load_cache_data
      path = File.expand_path(CACHE_FILENAME, output_path)
      yaml_str = File.exist?(path) ? File.read(path) : nil
      return unless yaml_str
      YAML.load(yaml_str)
    rescue Psych::Exception
      nil
    end

    def save_cache_data!
      path = File.expand_path(CACHE_FILENAME, output_path)
      File.write(path, YAML.dump(pb_cache))
    end

    def generate_rb_files
      base_cmd = PROTOC_CMD % {
        out_path: Shellwords.escape(output_path),
        lib_path: Shellwords.escape(protos_path)
      }
      files = []
      options['proto_files'].each do |matcher|
        files.concat(Dir[File.expand_path(matcher, protos_path)].to_a)
      end

      # TODO open3 to concurrent generate files
      files.uniq.map do |path|
        (fetch_pb_cache(path) || generate_pbfiles(base_cmd, path)).tap do |r|
          set_cache(path, r) if r
        end
      end.compact.flatten
    end

    # Returns:
    #   nil: Failedto generate
    #   [path1, path2, ...]: generated files
    def generate_pbfiles(base_cmd, path)
      Logger[:auto].debug { "Generate protobuf for #{path}" }
      cmd = base_cmd + " #{Shellwords.escape(path)}"
      sout_dir = Shellwords.escape(output_path)
      # remove suffix
      fname = File.basename(path).gsub(/\.[\w\-]+$/, '')
      out_files = [
        File.expand_path(fname + '_pb.rb', sout_dir),
        File.expand_path(fname + '_services_pb.rb', sout_dir)
      ]
      out_files.each { |opath| FileUtils.rm_f(opath) }

      out, err, status = Open3.capture3(cmd)
      if status.exitstatus != 0
        Logger[:auto].error { "Error of #{cmd}: #{err.presence || out}" }
        return nil
      elsif err.present?
        Logger[:auto].warn { "#{path}: #{err.presence || out}" }
      end
      out_files.select { |fp| File.exist?(fp) }
    end

    def set_cache(path, out_paths)
      pb_cache[path] = [
        Digest::SHA256.hexdigest(File.read(path)),
        out_paths.each_with_object({}) { |opath, r| r[opath] = Digest::SHA256.hexdigest(File.read(opath)) }
      ]
    end

    def fetch_pb_cache(path)
      pb_hex = Digest::SHA256.hexdigest(File.read(path))
      old_pb_hex, old_out_hexs = pb_cache[path]
      return unless pb_hex == old_pb_hex
      old_out_hexs.each do |opath, hex|
        return unless File.exist?(opath)
        return unless Digest::SHA256.hexdigest(File.read(opath)) == hex
      end
      old_out_hexs.keys
    end

    def load_protos(files)
      out_path = output_path
      Module.new.tap do |m|
        mid = [Digest::SHA256.hexdigest(files.join(',')), Time.now.to_f].join('_').tr('.', '')
        ApiProject::GRPCParser.const_set("ParsedModule_#{mid}", m)
        Google::Protobuf::DescriptorPool.reset_pb_pool!

        m.module_exec do
          @loaded_paths = []
          @pb_pool = Google::Protobuf::DescriptorPool.generated_pool
          @services = {}

          define_singleton_method(:pb_pool) { @pb_pool }
          define_singleton_method(:services) { @services }

          define_singleton_method(:require) do |path|
            Kernel.require(path)
          rescue LoadError => e
            file = File.expand_path("#{path}.rb", out_path)
            raise e unless File.exist?(file)
            load_code(file)
          end

          define_singleton_method(:load_code) do |path|
            return if @loaded_paths.include?(path)
            code = File.read(path)
            self.module_eval(code, path, 1)
            @loaded_paths << path
          end
        end

        files.each { |path| m.load_code(path) }
      end
    end
  end
end

Google::Protobuf::DescriptorPool.class_eval do
  unless @xjz_hack
    @xjz_hack = true
    def self.generated_pool
      Thread.current[:google_protobuf_dp] ||= new
    end

    def self.reset_pb_pool!
      Thread.current[:google_protobuf_dp] = nil
    end
  end
end
