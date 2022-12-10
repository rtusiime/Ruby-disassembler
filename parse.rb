dwarf_file = "llvmDump.txt"
assem_file = "objDump.txt"

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
                    aline2add[assem_num] = current_add
                    add2aline[current_add] = assem_num
                    assem_num = assem_num + 1
                end
            end
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

