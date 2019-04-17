{
  en: {
    number: {
      time_interval: lambda do |_key, number:, **_options|
        if number < 10 * 1000
          "#{number.to_i} ms"
        else
          "#{(number / 1000).to_i} s"
        end
      end
    }
  }
}
