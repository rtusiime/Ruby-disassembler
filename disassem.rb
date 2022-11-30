wasGood = system( "gcc -g3 -O1 -o 'test' #{ARGV[0]} " )
llvmDump = `llvm-dwarfdump --debug-line 'test'`
puts llvmDump
objDump  = `objdump -d 'test'`
puts objDump
file = File.new("#{ARGV[0]}_disassem.html", "w+")
file.puts "<!DOCTYPE html>"
file.puts "<HTML>"
file.puts "<HEAD>"
file.puts "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
file.puts "<style media='all' type='text/css'>"
file.puts "{box-sizing: border-box;}"
file.puts ".column {float: left; width: 50%; padding: 10px; height: 300px;}"
file.puts ".row:after {content: ""; display: table; clear: both;}"
file.puts "</style>"
file.puts "</HEAD>"
file.puts "<BODY>"
file.puts "<h2>#{ARGV[0]}</h2>"
file.puts "<div class=\"row\">"
file.puts " <div class=\"column\" style=\"background-color:#aaa;\">"
file.puts "<h2>Source</h2>"
File.open(ARGV[0]).each do |line| 
file.puts "<p> #{line} </p>"
end
file.puts "</div>"
file.puts "<div class=\"column\" style=\"background-color:#bbb;\">"
file.puts " <h2> Assembly </h2>"
file.puts " <p> #{objDump} </p>"
file.puts " </div>"
file.puts "</BODY></HTML>"
file.close()
