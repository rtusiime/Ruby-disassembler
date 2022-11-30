wasGood = system( "gcc -g3 -O1 -o 'test' #{ARGV[0]} " )
llvmDump = `llvm-dwarfdump --debug-line 'test'`
puts llvmDump
objDump  = `objdump -d 'test'`
puts objDump
fileHtml = File.new("disassem.html", "w+")
fileHtml.puts "<HTML>"
fileHtml.puts "<HEAD>"
fileHtml.puts "<style media='all' type='text/css'>"
fileHtml.puts "body {font-family: Helvetica Neue, sans-serif; font-size: 18px; color: #525252; padding: 0; margin: 0;background: #f2f2f2;}"
fileHtml.puts ".content {max-width:1180px; padding: 40px;}"
fileHtml.puts ".div1 {margin-top: 28px; margin-bottom: 1px; background-color: #fff; padding: 10px 40px; padding-bottom: 8px; }"
fileHtml.puts ".div2 {margin-top: 2px; height:25%; margin-bottom: 28px; background-color: #fff; padding: 10px 40px; padding-bottom: 8px; }"
fileHtml.puts ".header {background-color: white; height: 16%; min-height: 110px; position: relative; width: 100%; -webkit-user-select: none;}"
fileHtml.puts ".secondSection {background-color: #e8e8e8; height: 16%; min-height: 110px; position: relative; width: 100%; -webkit-user-select: none;}"
fileHtml.puts ".pass {color: #ffffff; background: #34d9a2; padding: 10px 20px 10px 20px; text-decoration: none; width:50px;}"
fileHtml.puts ".fail {color: #ffffff; background: #f25e6a; padding: 10px 20px 10px 20px; text-decoration: none; width:50px;}"
fileHtml.puts "</style>"
fileHtml.puts "</HEAD>"
fileHtml.puts "<BODY>"
fileHtml.puts "<DIV class='secondSection'><p>#{objDump}</p><p>#{llvmDump}</p></div>"
fileHtml.puts "</BODY></HTML>"
fileHtml.close()

