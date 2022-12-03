filename = 'llvm-dwarfdump.txt'
line2add = {}
add2line = {}
File.foreach(filename) do |line|
    case line
    when /^0x(.)*/
        array = line.split
        puts "#{array[0]} #{array[1]}"
        add = array[0].to_i(base=16)
        line_num = array[1].to_i
        puts "#{add} #{line_num}"
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
puts line2add
puts add2line