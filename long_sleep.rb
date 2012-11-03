# long_sleep.rb

require 'java'
class RuntimeView
  def display
    rt = java.lang.Runtime.getRuntime
    puts " Free memory: #{rt.freeMemory}"
    puts "Total memory: #{rt.totalMemory}"
    sleep 1000 * 60 * 60
  end
end

RuntimeView.new.display
