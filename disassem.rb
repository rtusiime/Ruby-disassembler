object_file = ARGV[0]
source_file = ARGV[1]
dwarf_file = "llvmDump.txt"
assem_file = "objDump.txt"
html_header_file = "header.txt"

# System command to compile c code, get drwaf table, get assembly code
llvmDump = system("llvm-dwarfdump --debug-line '#{object_file}' > #{dwarf_file}" )
objDump  = system("objdump -d '#{object_file}'' >  #{assem_file}")

# parse dwarf table to obtain mapping 
sline2add = {}
add2sline = {}
start_add = Float::INFINITY
end_add = -Float::INFINITY
File.foreach(dwarf_file) do |line|
    case line
    when /^0x(.)*/
        array = line.split
        # puts "#{array[0]} #{array[1]}"
        add = array[0].to_i(base=16)
        line_num = array[1].to_i
        # record the start and end add
        if (add < start_add)
            start_add = add
        end
        if (add > end_add)
            end_add = add
        end
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


file = File.new("#{object_file}_disassem.html", "w+")

File.foreach(html_header_file) do |line|
    file.puts line
end
file.puts "<h1>#{object_file}</h1>"

file.write <<-HTML
<table width="100%">
<tr>
<td width="49%">
<h2>source</h2>
<div id="source">
HTML

count = 1
File.open(source_file).each do |line|
	case line
        when /^$/ # empty line print an empty line
            file.puts "<button>&nbsp;&nbsp;#{count}</button> <span id=\"s#{count}\" aline=\"\"></span>"
        else
            line = line.chomp
            line = line.gsub("<","&lt;")
            line = line.gsub(">","&gt;")
            line = line.gsub(/\n/,"/n")
            if (sline2add.has_key?(count))
                a_add = sline2add[count]
                assem_lines = []
                a_add.each do |add|
                    aline = add2aline[add]
                    assem_lines.append("a"+aline.to_s)
                end
                assem_lines_str = assem_lines.join(" ")
                file.puts "<button onclick=\"sclick('s#{count}','#{assem_lines[0]}')\">&nbsp;&nbsp;#{count}</button> <span id=\"s#{count}\" aline= \"#{assem_lines_str}\">#{line}</span>" #adds sclick function if source line has corresponding addembly line
            else
                file.puts "<button>&nbsp;&nbsp;#{count}</button> <span id=\"s#{count}\" aline= \"\">#{line}</span>"
            end
    end
    count += 1;
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
	when /^[A-Fa-f0-9]+ <[A-Za-z0-9_.]+>:$/
	    arr = line.split
        addr = arr[0].to_i(base=16)
        # check start ?
        if(addr == start_add)
            reach = true
        end
        # check end ?
        if (addr >= end_add)
            break
        end
        if(reach)
            line = line.gsub("<","&lt;")
            line = line.gsub(">","&gt;")
            file.puts "#{line}"
        end
        next
    when /^$/
        if (reach)
            file.puts ""
        end
        next
	else
        if (reach)
	        # puts " bruhhhhhh we reached --> #{line}" 
            line.chomp!
            line = line.gsub("<","&lt;")
            line = line.gsub(">","&gt;")
            arr = line.split(':')
            addr = arr[0].to_i(base=16)
            source_lines = []
            if (add2sline.has_key?(addr))
                add2sline[addr].each do |val|
                    source_lines.append("s"+val.to_s)
                end
            source_lines_str = source_lines.join(" ")
            file.puts "<button onclick=\"aclick('a#{count}','#{source_lines[0]}')\">#{addr.to_s(16)}</button><span id=\"a#{count}\" sline= \"#{source_lines_str}\">#{arr[1]}</span>"
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
