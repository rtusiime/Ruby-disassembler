source_file = ARGV[0]
dwarf_file = "llvmDump.txt"
assem_file = "objDump.txt"

# System command to compile c code, get drwaf table, get assembly code
wasGood = system( "gcc -g3 -O1 -o 'test' #{source_file} " )
llvmDump = system("llvm-dwarfdump --debug-line 'test' > #{dwarf_file}" )
objDump  = system("objdump -d 'test' >  #{assem_file}")

# parse dwarf table to obtain mapping 
sline2add = {}
add2sline = {}
start_add = 0 
end_add = 0
File.foreach(dwarf_file) do |line|
    case line
    when /^0x(.)*/
        array = line.split
        # puts "#{array[0]} #{array[1]}"
        add = array[0].to_i(base=16)
        line_num = array[1].to_i
        # record the start and end add
        if (start_add==0)
            start_add = add
        end
        end_add = add
        # puts "#{add} #{line_num}"
        # create source line num to address mapping
        if (sline2add.has_key?(line_num))
            sline2add[line_num].append(add)
        else
            sline2add[line_num] = [add]
        end
        # create address mapping to source code num mapping
        if (add2sline.has_key?(add))
            add2sline[add].append(line_num)
        else
            add2sline[add] = [line_num]
        end
        next
    end
end

# parse the objdump to fill out the omitted instructions
aline2add = {}
add2aline = {}
previous_add = 0
previous_line = 0
reach = false
assem_num = 1
File.foreach(assem_file) do |line|
    case line
    when /(.)*:$/
        next
    when /^$/
        next
    else
        array = line.split
        case array[0]
        when /^[A-Fa-f0-9]+:$/ # match hex number
            current_add = array[0][0..-2].to_i(base=16)
            # skip to start address
            if (!reach)
                if(current_add==start_add)
                    reach = true
                    previous_add = start_add
                    previous_line = add2sline[previous_add].last
                    aline2add[assem_num] = start_add
                    add2aline[start_add] = assem_num
                    assem_num = assem_num + 1
                end
                next
            end
            # passed start address
            # puts "#{current_add.to_s(16)},#{previous_add.to_s(16)},#{previous_line}"
            if (!add2sline.has_key?(current_add))
                if (add2sline.has_key?(previous_add))
                    add2sline[current_add] = [previous_line]
                    sline2add[previous_line].append(current_add)
                end
            end
            aline2add[assem_num] = current_add
            add2aline[current_add] = assem_num
            assem_num = assem_num + 1
            previous_add = current_add
            previous_line = add2sline[current_add].last
        end
    end
end

# remove duplicate
sline2add.each do |key,value|
    sline2add[key] = value.uniq
end
add2sline.each do |key,value|
    add2sline[key] = value.uniq
end

# print the mapping
puts "Line to Address Mapping"
sline2add.each do |key,value|
    value_hex = value.map{|x| x.to_s(16)}
    puts "#{key} => #{value_hex}"
end

puts "Address to Line Mapping"
add2sline.each do |key,value|
    puts "#{key.to_s(16)} => #{value}"
end

puts "Assembly line to address Mapping"
aline2add.each do |key,value|
    puts "#{key} => #{value.to_s(16)}"
end

puts "Address to Assembly Line Mapping"
add2aline.each do |key,value|
    puts "#{key.to_s(16)} => #{value}"
end

=begin
For Kevin
The six things you will need:

sline2add - source code line to LIST of assembly address
add2sline - assembly address to LIST of source code line 
aline2add - assembly line to ONE assembly address
add2aline - assembly address to ONE assembly line
start_add - the address for the first assembly instruction
end_add - the address for the last assembly instruction

NOTE: 
I store the address in decimal form, to convert it to hex string, use "add.to_s(16)"
=end

# write actual html code
file = File.new("#{ARGV[0]}_disassem.html", "w+")
file.write <<-HTML

<!doctype html>
<html>
<!--
    This is the code for HTML file that will be generated once the user runs the program.
    It's greatly inspired by the code from Prof Scott's ascii_disassem.html file. The javascript,
    HMTL, and CSS have mostly been copied word for word from the doc.
-->
<style>
button {
    border: none;
    margin: none;
    font-family: "Courier New", "Courier", "monospace";
    background-color: Azure;
}
button[onclick] {
    background-color: LightCyan;
}
button[onclick]:hover {
    background-color: PaleGreen;
}
#assembly {
    height: 88vh;
    overflow: auto;
    font-family: "Courier New", "Courier", "monospace";
    font-size: 80%;
    white-space: pre
}
#source {
    height: 88vh;
    overflow: auto;
    font-family: "Courier New", "Courier", "monospace";
    font-size: 80%;
    white-space: pre
}
table {
    border-spacing: 0px;
}
td {
    padding: 0px;
    padding-right: 15px;
}
</style>

<body>
<script>
// scroll line into the middle of its respective subwindow
function reveal(line) {
  const element = document.getElementById(line);
  element.scrollIntoView({
    behavior: 'auto',
    block: 'center',
    inline: 'center'
  });
}
// green-highlight aline,
// yellow-highlight all source lines that contributed to aline,
// and scroll sline into view
function aclick(aline, sline) {
  const sLines = document.querySelectorAll("span[aline]");  // slines have an aline list
  const aLines = document.querySelectorAll("span[sline]");  // alines have an sline list
  // clear all assembly lines
  aLines.forEach((l) => {
    l.style.backgroundColor = 'white';
  })
  sLines.forEach((sl) => {
    if (sl.matches("span[aline~="+aline+"]")) {
        sl.style.backgroundColor = 'yellow';
        aLines.forEach((al) => {
          if (al.matches("span[sline~="+sl.id+"]")) {
            al.style.backgroundColor = 'PapayaWhip';
          }
        })
    } else {
        sl.style.backgroundColor = 'white';
    }
  })
  const l = document.getElementById(aline);
  l.style.backgroundColor = 'PaleGreen';
  reveal(sline);
}
// green-highlight sline,
// yellow-highlight all assembly lines that correspond to sline,
// and scroll aline into view
function sclick(sline, aline) {
  const aLines = document.querySelectorAll("span[sline]");  // alines have an sline list
  const sLines = document.querySelectorAll("span[aline]");  // slines have an aline list
  // clear all source lines
  sLines.forEach((l) => {
    l.style.backgroundColor = 'white';
  })
  aLines.forEach((l) => {
    if (l.matches("span[sline~="+sline+"]")) {
        l.style.backgroundColor = 'yellow';
    } else {
        l.style.backgroundColor = 'white';
    }
  })
  const l = document.getElementById(sline);
  l.style.backgroundColor = 'PaleGreen';
  reveal(aline);
}
</script>

<h1>#{ARGV[0]}</h1>

<table width="100%">
<tr>
<td width="49%">
<h2>source</h2>
<div id="source">
HTML

count = 1
File.open(ARGV[0]).each do |line|
	case line
	when /^$/
	next
	else
	line = line.chomp
    line = line.gsub("<","&lt;")
    line = line.gsub(">","&gt;")
    line = line.gsub(/\n/,"/n")
    assem_lines = []
    if (sline2add.has_key?(count))
        sline2add[count].each do |val|
		aline = add2aline[val]  
		assem_lines.append("a"+aline.to_s)
	end
	#puts "assem lines for count = #{count} are --->#{assem_lines}"
        file.puts "<button onclick=\"sclick('s#{count}','#{assem_lines[0]}')\">&nbsp;&nbsp;#{count}</button> <span id=\"s#{count}\" aline= \"#{assem_lines}\">#{line}</span>" #adds sclick function if source line has corresponding addembly line
    else
    file.puts "<button>&nbsp;&nbsp;#{count}</button> <span id=\"s#{count}\" aline= \"#{assem_lines}\">#{line}</span>"
    end
    count += 1;
	end
end

file.write <<-HTML
</div>
</td>
<td width="49%">
<h2>assembly</h2>
<div id="assembly">
HTML

reach = false
count = 1
File.open(assem_file).each do |line|
	case line
	when /[\d]+\s<[\w]+>:$/
	    arr = line.split
        addr = arr[0].to_i(base=16)
        if(addr == start_add)
            reach = true
        end
        if(reach)
            line = line.gsub("<","&lt;")
            line = line.gsub(">","&gt;")
            file.puts "#{line}"
        end
        next
    when /^$/
        if (reach)
            file.puts "#{line}"
        end
        next
	else
        if (reach)
	puts " bruhhhhhh we reached --> #{line}" 
            line.chomp!
            line = line.gsub("<","&lt;")
            line = line.gsub(">","&gt;")
            arr = line.split(':', -1)
            addr = arr[0].to_i(base=16)
            source_lines = []
            if (add2sline.has_key?(addr))
                add2sline[addr].each do |val|
                    source_lines.append("s"+val.to_s)
                end
            file.puts "<button onclick=\"aclick('a#{count}','#{source_lines[0]}')\">#{addr}</button><span id=\"a#{count}\" sline= \"#{source_lines}\">#{line}</span>"
            end
            if (addr == end_add)
                break
            end
            count += 1;
        end
    end
end
file.write <<-HTML
</div>
</td>
</tr>
</table>
</body>
</html>
HTML
file.close()
