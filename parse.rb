dwarf_file = "llvmDump.txt"
assem_file = "objDump.txt"

line2add = {}
add2line = {}
start_add = 0 
File.foreach(dwarf_file) do |line|
    case line
    when /^0x(.)*/
        array = line.split
        # puts "#{array[0]} #{array[1]}"
        add = array[0].to_i(base=16)
        line_num = array[1].to_i
        if (start_add==0)
            start_add = add
        end
        # puts "#{add} #{line_num}"
        # create source line num to address mapping
        if (line2add.has_key?(line_num))
            line2add[line_num].append(add)
        else
            line2add[line_num] = [add]
        end
        # create address mapping to source code num mapping
        if (add2line.has_key?(add))
            add2line[add].append(line_num)
        else
            add2line[add] = [line_num]
        end

        next
    end
end

# parse the objdump to fill out the omitted instructions
previous_add = 0
previous_line = 0
reach = false
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
                    previous_line = add2line[previous_add].last
                end
                next
            end
            # passed start address
            # puts "#{current_add.to_s(16)},#{previous_add.to_s(16)},#{previous_line}"
            if (!add2line.has_key?(current_add))
                if (add2line.has_key?(previous_add))
                    add2line[current_add] = [previous_line]
                    line2add[previous_line].append(current_add)
                end
            end
            previous_add = current_add
            previous_line = add2line[current_add].last
        end
    end
end

# remove duplicate
line2add.each do |key,value|
    line2add[key] = value.uniq
end
add2line.each do |key,value|
    add2line[key] = value.uniq
end

# print the mapping
puts "Line to Address Mapping"
line2add.each do |key,value|
    value_hex = value.map{|x| x.to_s(16)}
    puts "#{key} => #{value_hex}"
end

puts "Address to Line Mapping"
add2line.each do |key,value|
    puts "#{key.to_s(16)} => #{value}"
end
