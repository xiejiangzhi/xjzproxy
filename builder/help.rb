def cmd(str, quiet: false)
  puts "$ #{str}" unless quiet
  exit 1 unless Kernel.system(str)
end

def mix_str(name, sl = 3, ll = 50, r = 5)
  len = name.size
  arr = []
  i = 0
  len.times do
    l = sl + rand(r)
    arr << name.slice(i, l)
    i += l
    break if i >= len
  end
  arr.map!(&:inspect)
  t = ''
  arr.each_with_index do |v, i|
    t << v
    if t.length >= ll
      t = ''
      arr[i] = "\n" + arr[i]
    end
  end
  arr.join('+')
end

def mix_str2(str)
  "#{str.bytes.inspect}.pack('C*')"
end

def encode_code(code, sl = 65, ll = 65)
  ecode = code.split('').map { |s| s.ord - 1 }.pack('C*')
  ecode = mix_str(ecode, sl, ll)
  "instance_eval((#{ecode}).unpack('C*').map{|v|(v+1).chr}.join)\n"
end
