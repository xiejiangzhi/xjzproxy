module Xjz
  unless self.respond_to?(:_load_file)
    def self._load_file(path)
      path.delete_suffix!('.rb') if path.end_with?('.rb')
      require File.expand_path(path, $root)
    end
  end

  def self.load_file(path)
    if path =~ /^(xjz)\//
      path = "src/#{path}"
    elsif path.start_with?('./') && Dir.pwd == $root
      path.delete_prefix!('./')
    elsif path.start_with?($root)
      path.delete_prefix!($root + '/')
    else
      raise "Invalid load path #{path}"
    end

    path << '.rb' unless path.end_with?('.rb')
    _load_file(path)
  end
end
