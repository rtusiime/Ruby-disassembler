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
	line = line.chomp!
    assem_lines = []
    if (sline2add.has_key?(count))
        sline2add[count].each do |val|
		aline = add2aline[val]  
		assem_lines.append("a"+aline.to_s)
	end
	puts "assem lines for count = #{count} are --->#{assem_lines}"
        file.puts "<button onclick=\"sclick('s#{count}','#{assem_lines[0]}')\">&nbsp;&nbsp;#{count}</button> <span id=\"s#{count}\" aline= \"#{assem_lines}\">#{line}</span>" #adds sclick function if source line has corresponding addembly line
    else
    file.puts "<button>&nbsp;&nbsp;#{count}</button> <span id=\"s#{count}\" aline= \"#{assem_lines}\">#{line}</span>"
    end
    count += 1;
	end
end

file.write <<-HTML
<button onclick="sclick('s36','a1')">&nbsp;36</button> <span id="s36" aline="a1 a2"                            >static void show_char(int c) {</span>
<button onclick="sclick('s37','a3')">&nbsp;37</button> <span id="s37" aline="a3 a4 a5 a6 a7 a8 a9 a10"         >    printf(" %#4x  %#4o  %3d    %s\n", c, c, c, value[c]);</span>
<button onclick="sclick('s38','a11')">&nbsp;38</button> <span id="s38" aline="a11 a12"                         >}</span>
<button           >&nbsp;39</button> <span id="s39" aline=""                                                   ></span>
<button onclick="sclick('s40','a13')">&nbsp;40</button> <span id="s40" aline="a13 a14 a15 a16 a17"             >int main(int argc, char **argv) {</span>
<button onclick="sclick('s41','a18')">&nbsp;41</button> <span id="s41" aline="a18"                             >    struct termios orig, new;</span>
<button onclick="sclick('s42','a18')">&nbsp;42</button> <span id="s42" aline="a18"                             >    int base, current, last, lastlast;</span>
<button onclick="sclick('s43','a18')">&nbsp;43</button> <span id="s43" aline="a18 a113 a114"                   >    current = last = lastlast = -1;</span>
<button onclick="sclick('s44','a18')">&nbsp;44</button> <span id="s44" aline="a18 a19 a20 a21"                 >    if (argc &gt; 1) {</span>
<button onclick="sclick('s45','a22')">&nbsp;45</button> <span id="s45" aline="a22 a23 a24"                     >        if (*argv[1] == '-') {</span>
<button onclick="sclick('s46','a32')">&nbsp;46</button> <span id="s46" aline="a32 a35 a36 a37 a38"             >            for (current = 0; current &lt;= 127; current++)</span>
<button onclick="sclick('s47','a33')">&nbsp;47</button> <span id="s47" aline="a33 a34 a123"                    >            show_char(current);</span>
<button           >&nbsp;48</button> <span id="s48" aline=""                                                   >        } else {</span>
<button onclick="sclick('s49','a75')">&nbsp;49</button> <span id="s49" aline="a75 a76 a77 a123 a124"           >            for (int i = 1; i &lt; argc; i++) {</span>
<button onclick="sclick('s50','a78')">&nbsp;50</button> <span id="s50" aline="a78"                             >                char *cp = argv[i];</span>
<button onclick="sclick('s51','a79')">&nbsp;51</button> <span id="s51" aline="a79"                             >                current = 0;</span>
<button onclick="sclick('s52','a44')">&nbsp;52</button> <span id="s52" aline="a44 a79 a80 a81 a82 a83 a84 a85" >                switch (*cp) {</span>
<button           >&nbsp;53</button> <span id="s53" aline=""                                                   >                case '0':</span>
<button onclick="sclick('s54','a39')">&nbsp;54</button> <span id="s54" aline="a39 a40"                         >                    base = 8;</span>
<button onclick="sclick('s55','a39')">&nbsp;55</button> <span id="s55" aline="a39"                             >                    cp++;</span>
<button onclick="sclick('s56','a40')">&nbsp;56</button> <span id="s56" aline="a40 a41 a42 a43"                 >                    if (*cp != 'x')</span>
<button           >&nbsp;57</button> <span id="s57" aline=""                                                   >                        break;</span>
<button           >&nbsp;58</button> <span id="s58" aline=""                                                   >                    /* else fall through */</span>
<button           >&nbsp;59</button> <span id="s59" aline=""                                                   >                case 'x':</span>
<button onclick="sclick('s60','a30')">&nbsp;60</button> <span id="s60" aline="a30 a31 a32 a45 a46"             >                    base = 16;</span>
<button onclick="sclick('s61','a45')">&nbsp;61</button> <span id="s61" aline="a45"                             >                    cp++;</span>
<button onclick="sclick('s62','a46')">&nbsp;62</button> <span id="s62" aline="a46 a47"                         >                    break;</span>
<button           >&nbsp;63</button> <span id="s63" aline=""                                                   >                default:</span>
<button           >&nbsp;64</button> <span id="s64" aline=""                                                   >                    base = 10;</span>
<button           >&nbsp;65</button> <span id="s65" aline=""                                                   >                }</span>
<button onclick="sclick('s66','a56')">&nbsp;66</button> <span id="s66" aline="a56 a57"                         >                for (;; ++cp) {</span>
<button onclick="sclick('s67','a57')">&nbsp;67</button> <span id="s67" aline="a57"                             >                    int d;</span>
<button onclick="sclick('s68','a25')">&nbsp;68</button> <span id="s68" aline="a25 a26 a27 a28 a29 a30 a57 a58
                                                               a59 a60 a61 a86 a87 a88 a89"                    >                    if (!isxdigit (*cp))</span>
<button           >&nbsp;69</button> <span id="s69" aline=""                                                   >                        break;</span>
<button onclick="sclick('s70','a62')">&nbsp;70</button> <span id="s70" aline="a62 a63"                         >                    if (isdigit (*cp))</span>
<button onclick="sclick('s71','a64')">&nbsp;71</button> <span id="s71" aline="a64 a65 a66"                     >                        d = *cp - '0';</span>
<button onclick="sclick('s72','a48')">&nbsp;72</button> <span id="s72" aline="a48 a49"                         >                    else if (isupper (*cp))</span>
<button onclick="sclick('s73','a50')">&nbsp;73</button> <span id="s73" aline="a50 a51"                         >                        d = *cp - 'A' + 10;</span>
<button           >&nbsp;74</button> <span id="s74" aline=""                                                   >                    else</span>
<button onclick="sclick('s75','a67')">&nbsp;75</button> <span id="s75" aline="a67 a68 a69 a70"                 >                        d = *cp - 'a' + 10;</span>
<button onclick="sclick('s76','a52')">&nbsp;76</button> <span id="s76" aline="a52 a53"                         >                    if (d &gt; base)</span>
<button           >&nbsp;77</button> <span id="s77" aline=""                                                   >                        break;</span>
<button onclick="sclick('s78','a54')">&nbsp;78</button> <span id="s78" aline="a54 a55 a56"                     >                    current = base * current + d;</span>
<button           >&nbsp;79</button> <span id="s79" aline=""                                                   >                }</span>
<button onclick="sclick('s80','a70')">&nbsp;80</button> <span id="s80" aline="a70 a71"                         >                if (*cp != '\0') {</span>
<button onclick="sclick('s81','a89')">&nbsp;81</button> <span id="s81" aline="a89 a90 a91"                     >                    printf("%s???\n", cp);</span>
<button onclick="sclick('s82','a92')">&nbsp;82</button> <span id="s82" aline="a92 a93 a118"                    >                    exit(1);</span>
<button           >&nbsp;83</button> <span id="s83" aline=""                                                   >                }</span>
<button onclick="sclick('s84','a72')">&nbsp;84</button> <span id="s84" aline="a72 a73 a118 a119 a120"          >                if (current &lt;= 127) {</span>
<button onclick="sclick('s85','a74')">&nbsp;85</button> <span id="s85" aline="a74 a75"                         >                    show_char(current);</span>
<button           >&nbsp;86</button> <span id="s86" aline=""                                                   >                }</span>
<button onclick="sclick('s87','a94')">&nbsp;87</button> <span id="s87" aline="a94 a95 a96 a97 a98 a99"         >                else printf("value %s out of range\n", argv[i]);</span>
<button           >&nbsp;88</button> <span id="s88" aline=""                                                   >            }</span>
<button           >&nbsp;89</button> <span id="s89" aline=""                                                   >        }</span>
<button           >&nbsp;90</button> <span id="s90" aline=""                                                   >    } else {</span>
<button onclick="sclick('s91','a99')">&nbsp;91</button> <span id="s91" aline="a99 a100 a101 a102"              >        (void) tcgetattr(2, &amp;orig);</span>
<button onclick="sclick('s92','a103')">&nbsp;92</button> <span id="s92" aline="a103 a104 a105 a106"            >        new = orig;</span>
<button onclick="sclick('s93','a107')">&nbsp;93</button> <span id="s93" aline="a107 a108"                      >        (void) cfmakeraw(&amp;new);</span>
<button           >&nbsp;94</button> <span id="s94" aline=""                                                   ></span>
<button onclick="sclick('s95','a109')">&nbsp;95</button> <span id="s95" aline="a109 a110 a111 a112"            >        (void) tcsetattr(2, TCSANOW, &amp;new);</span>
<button onclick="sclick('s96','a113')">&nbsp;96</button> <span id="s96" aline="a113 a115 a123 a125 a126 a127
                                                                          a128 a129 a130"                      >        while (((current = (0177 &amp; getchar())) != last) || (current != lastlast)) {</span>
<button onclick="sclick('s97','a116')">&nbsp;97</button> <span id="s97" aline="a116 a121"                      >            lastlast = last;</span>
<button onclick="sclick('s98','a116')">&nbsp;98</button> <span id="s98" aline="a116 a122"                      >            last = current;</span>
<button onclick="sclick('s99','a116')">&nbsp;99</button> <span id="s99" aline="a116 a117"                      >            show_char(current);</span>
<button onclick="sclick('s100','a118')">100</button> <span id="s100" aline="a118"                              >            putchar('\r');      // device is raw</span>
<button           >101</button> <span id="s101" aline=""                                                       >        }</span>
<button onclick="sclick('s102','a131')">102</button> <span id="s102" aline="a131 a132 a133 a134"               >        (void) tcsetattr(2, TCSANOW, &amp;orig);</span>
<button           >103</button> <span id="s103" aline=""                                                       >    }</span>
<button onclick="sclick('s104','a135')">104</button> <span id="s104" aline="a135 a136 a137 a138 a139 a140 a141">}</span>
</div>
</td>
<td width="49%">
<h2>assembly</h2>
<!--
    In each span of the following division, the id indicates the line number, which is
    used to identify the line for scrollIntoView.  The sline attribute lists the source
    line(s) associated with the assembly line -- the ones that should, if clicked, cause
    this assembly line to highlight.

    Each call of aclick(a, s) is passed two arguments.  The initial argument indicates
    which assembly line this is -- it will cause any source line(s) associated with
    that assembly line to be highlighted, along with any other assembly line(s)
    associated with that source line.  The second argument is the lowest-numbered source
    line associated with that assembly line; this line will be scrolled into view in
    the source pane.
-->
<div id="assembly">
0000000000401196 &lt;show_char&gt;:

<button onclick="aclick('a1','s36')"   >401196</button><span id="a1"   sline="s36             "> 48 83 ec 08            sub   $0x8,%rsp</span>
<button onclick="aclick('a2','s36')"   >40119a</button><span id="a2"   sline="s36             "> 89 fe                  mov   %edi,%esi</span>
<button onclick="aclick('a3','s37')"   >40119c</button><span id="a3"   sline="s37             "> 48 63 c7               movslq%edi,%rax</span>
<button onclick="aclick('a4','s37')"   >40119f</button><span id="a4"   sline="s37             "> 4c 8b 04 c5 80 40 40   mov   0x404080(,%rax,8),%r8</span>
<button onclick="aclick('a5','s37')"   >4011a6</button><span id="a5"   sline="s37             "> 00</span>
<button onclick="aclick('a6','s37')"   >4011a7</button><span id="a6"   sline="s37             "> 89 f9                  mov   %edi,%ecx</span>
<button onclick="aclick('a7','s37')"   >4011a9</button><span id="a7"   sline="s37             "> 89 fa                  mov   %edi,%edx</span>
<button onclick="aclick('a8','s37')"   >4011ab</button><span id="a8"   sline="s37             "> bf 10 20 40 00         mov   $0x402010,%edi</span>
<button onclick="aclick('a9','s37')"   >4011b0</button><span id="a9"   sline="s37             "> b8 00 00 00 00         mov   $0x0,%eax</span>
<button onclick="aclick('a10','s37')"  >4011b5</button><span id="a10"  sline="s37             "> e8 76 fe ff ff         call  401030&nbsp;&lt;printf@plt&gt;</span>
<button onclick="aclick('a11','s38')"  >4011ba</button><span id="a11"  sline="s38             "> 48 83 c4 08            add   $0x8,%rsp</span>
<button onclick="aclick('a12','s38')"  >4011be</button><span id="a12"  sline="s38             "> c3                     ret</span>

00000000004011bf &lt;main&gt;:

<button onclick="aclick('a13','s40')"  >4011bf</button><span id="a13"  sline="s40            "> 41 55                  push  %r13</span>
<button onclick="aclick('a14','s40')"  >4011c1</button><span id="a14"  sline="s40            "> 41 54                  push  %r12</span>
<button onclick="aclick('a15','s40')"  >4011c3</button><span id="a15"  sline="s40            "> 55                     push  %rbp</span>
<button onclick="aclick('a16','s40')"  >4011c4</button><span id="a16"  sline="s40            "> 53                     push  %rbx</span>
<button onclick="aclick('a17','s40')"  >4011c5</button><span id="a17"  sline="s40            "> 48 81 ec 88 00 00 00   sub   $0x88,%rsp</span>
<button onclick="aclick('a18','s41')"  >4011cc</button><span id="a18"  sline="s41 s42 s43 s44"> 83 ff 01               cmp   $0x1,%edi</span>
<button onclick="aclick('a19','s44')"  >4011cf</button><span id="a19"  sline="s44            "> 0f 8e 1a 01 00 00      jle   4012ef&nbsp;&lt;main+0x130&gt;</span>
<button onclick="aclick('a20','s44')"  >4011d5</button><span id="a20"  sline="s44            "> 41 89 fd               mov   %edi,%r13d</span>
<button onclick="aclick('a21','s44')"  >4011d8</button><span id="a21"  sline="s44            "> 49 89 f4               mov   %rsi,%r12</span>
<button onclick="aclick('a22','s45')"  >4011db</button><span id="a22"  sline="s45            "> 48 8b 46 08            mov   0x8(%rsi),%rax</span>
<button onclick="aclick('a23','s45')"  >4011df</button><span id="a23"  sline="s45            "> 80 38 2d               cmpb  $0x2d,(%rax)</span>
<button onclick="aclick('a24','s45')"  >4011e2</button><span id="a24"  sline="s45            "> 74 21                  je    401205&nbsp;&lt;main+0x46&gt;</span>
<button onclick="aclick('a25','s68')"  >4011e4</button><span id="a25"  sline="s68            "> e8 b7 fe ff ff         call  4010a0&nbsp;&lt;__ctype_b_loc@plt&gt;</span>
<button onclick="aclick('a26','s68')"  >4011e9</button><span id="a26"  sline="s68            "> 48 89 c5               mov   %rax,%rbp</span>
<button onclick="aclick('a27','s68')"  >4011ec</button><span id="a27"  sline="s68            "> 49 8d 5c 24 08         lea   0x8(%r12),%rbx</span>
<button onclick="aclick('a28','s68')"  >4011f1</button><span id="a28"  sline="s68            "> 41 8d 45 fe            lea   -0x2(%r13),%eax</span>
<button onclick="aclick('a29','s68')"  >4011f5</button><span id="a29"  sline="s68            "> 4d 8d 64 c4 10         lea   0x10(%r12,%rax,8),%r12</span>
<button onclick="aclick('a30','s60')"  >4011fa</button><span id="a30"  sline="s68 s60        "> 41 bd 10 00 00 00      mov   $0x10,%r13d</span>
<button onclick="aclick('a31','s60')"  >401200</button><span id="a31"  sline="s60            "> e9 97 00 00 00         jmp   40129c&nbsp;&lt;main+0xdd&gt;</span>
<button onclick="aclick('a32','s46')"  >401205</button><span id="a32"  sline="s60 s46        "> bb 00 00 00 00         mov   $0x0,%ebx</span>
<button onclick="aclick('a33','s47')"  >40120a</button><span id="a33"  sline="s47            "> 89 df                  mov   %ebx,%edi</span>
<button onclick="aclick('a34','s47')"  >40120c</button><span id="a34"  sline="s47            "> e8 85 ff ff ff         call  401196&nbsp;&lt;show_char&gt;</span>
<button onclick="aclick('a35','s46')"  >401211</button><span id="a35"  sline="s46            "> 83 c3 01               add   $0x1,%ebx</span>
<button onclick="aclick('a36','s46')"  >401214</button><span id="a36"  sline="s46            "> 81 fb 80 00 00 00      cmp   $0x80,%ebx</span>
<button onclick="aclick('a37','s46')"  >40121a</button><span id="a37"  sline="s46            "> 75 ee                  jne   40120a&nbsp;&lt;main+0x4b&gt;</span>
<button onclick="aclick('a38','s46')"  >40121c</button><span id="a38"  sline="s46            "> e9 5f 01 00 00         jmp   401380&nbsp;&lt;main+0x1c1&gt;</span>
<button onclick="aclick('a39','s54')"  >401221</button><span id="a39"  sline="s54 s55        "> 49 8d 71 01            lea   0x1(%r9),%rsi</span>
<button onclick="aclick('a40','s54')"  >401225</button><span id="a40"  sline="s56 s54        "> b9 08 00 00 00         mov   $0x8,%ecx</span>
<button onclick="aclick('a41','s56')"  >40122a</button><span id="a41"  sline="s56            "> 41 80 79 01 78         cmpb  $0x78,0x1(%r9)</span>
<button onclick="aclick('a42','s56')"  >40122f</button><span id="a42"  sline="s56            "> 0f 85 82 00 00 00      jne   4012b7&nbsp;&lt;main+0xf8&gt;</span>
<button onclick="aclick('a43','s56')"  >401235</button><span id="a43"  sline="s56            "> eb 03                  jmp   40123a&nbsp;&lt;main+0x7b&gt;</span>
<button onclick="aclick('a44','s52')"  >401237</button><span id="a44"  sline="s52            "> 4c 89 ce               mov   %r9,%rsi</span>
<button onclick="aclick('a45','s60')"  >40123a</button><span id="a45"  sline="s60 s61        "> 48 83 c6 01            add   $0x1,%rsi</span>
<button onclick="aclick('a46','s60')"  >40123e</button><span id="a46"  sline="s62 s60        "> 44 89 e9               mov   %r13d,%ecx</span>
<button onclick="aclick('a47','s62')"  >401241</button><span id="a47"  sline="s62            "> eb 74                  jmp   4012b7&nbsp;&lt;main+0xf8&gt;</span>
<button onclick="aclick('a48','s72')"  >401243</button><span id="a48"  sline="s72            "> f6 c4 01               test  $0x1,%ah</span>
<button onclick="aclick('a49','s72')"  >401246</button><span id="a49"  sline="s72            "> 74 31                  je    401279&nbsp;&lt;main+0xba&gt;</span>
<button onclick="aclick('a50','s73')"  >401248</button><span id="a50"  sline="s73            "> 0f be c2               movsbl%dl,%eax</span>
<button onclick="aclick('a51','s73')"  >40124b</button><span id="a51"  sline="s73            "> 83 e8 37               sub   $0x37,%eax</span>
<button onclick="aclick('a52','s76')"  >40124e</button><span id="a52"  sline="s76            "> 39 c8                  cmp   %ecx,%eax</span>
<button onclick="aclick('a53','s76')"  >401250</button><span id="a53"  sline="s76            "> 7f 2f                  jg    401281&nbsp;&lt;main+0xc2&gt;</span>
<button onclick="aclick('a54','s78')"  >401252</button><span id="a54"  sline="s78            "> 0f af f9               imul  %ecx,%edi</span>
<button onclick="aclick('a55','s78')"  >401255</button><span id="a55"  sline="s78            "> 01 c7                  add   %eax,%edi</span>
<button onclick="aclick('a56','s66')"  >401257</button><span id="a56"  sline="s78 s66        "> 48 83 c6 01            add   $0x1,%rsi</span>
<button onclick="aclick('a57','s66')"  >40125b</button><span id="a57"  sline="s66 s67 s68    "> 0f b6 16               movzbl(%rsi),%edx</span>
<button onclick="aclick('a58','s68')"  >40125e</button><span id="a58"  sline="s68            "> 48 0f be c2            movsbq%dl,%rax</span>
<button onclick="aclick('a59','s68')"  >401262</button><span id="a59"  sline="s68            "> 41 0f b7 04 40         movzwl(%r8,%rax,2),%eax</span>
<button onclick="aclick('a60','s68')"  >401267</button><span id="a60"  sline="s68            "> f6 c4 10               test  $0x10,%ah</span>
<button onclick="aclick('a61','s68')"  >40126a</button><span id="a61"  sline="s68            "> 74 15                  je    401281&nbsp;&lt;main+0xc2&gt;</span>
<button onclick="aclick('a62','s70')"  >40126c</button><span id="a62"  sline="s70            "> f6 c4 08               test  $0x8,%ah</span>
<button onclick="aclick('a63','s70')"  >40126f</button><span id="a63"  sline="s70            "> 74 d2                  je    401243&nbsp;&lt;main+0x84&gt;</span>
<button onclick="aclick('a64','s71')"  >401271</button><span id="a64"  sline="s71            "> 0f be c2               movsbl%dl,%eax</span>
<button onclick="aclick('a65','s71')"  >401274</button><span id="a65"  sline="s71            "> 83 e8 30               sub   $0x30,%eax</span>
<button onclick="aclick('a66','s71')"  >401277</button><span id="a66"  sline="s71            "> eb d5                  jmp   40124e&nbsp;&lt;main+0x8f&gt;</span>
<button onclick="aclick('a67','s75')"  >401279</button><span id="a67"  sline="s75            "> 0f be c2               movsbl%dl,%eax</span>
<button onclick="aclick('a68','s75')"  >40127c</button><span id="a68"  sline="s75            "> 83 e8 57               sub   $0x57,%eax</span>
<button onclick="aclick('a69','s75')"  >40127f</button><span id="a69"  sline="s75            "> eb cd                  jmp   40124e&nbsp;&lt;main+0x8f&gt;</span>
<button onclick="aclick('a70','s75')"  >401281</button><span id="a70"  sline="s75 s80        "> 84 d2                  test  %dl,%dl</span>
<button onclick="aclick('a71','s80')"  >401283</button><span id="a71"  sline="s80            "> 75 3d                  jne   4012c2&nbsp;&lt;main+0x103&gt;</span>
<button onclick="aclick('a72','s84')"  >401285</button><span id="a72"  sline="s84            "> 83 ff 7f               cmp   $0x7f,%edi</span>
<button onclick="aclick('a73','s84')"  >401288</button><span id="a73"  sline="s84            "> 7f 51                  jg    4012db&nbsp;&lt;main+0x11c&gt;</span>
<button onclick="aclick('a74','s85')"  >40128a</button><span id="a74"  sline="s85            "> e8 07 ff ff ff         call  401196&nbsp;&lt;show_char&gt;</span>
<button onclick="aclick('a75','s49')"  >40128f</button><span id="a75"  sline="s85 s49        "> 48 83 c3 08            add   $0x8,%rbx</span>
<button onclick="aclick('a76','s49')"  >401293</button><span id="a76"  sline="s49            "> 4c 39 e3               cmp   %r12,%rbx</span>
<button onclick="aclick('a77','s49')"  >401296</button><span id="a77"  sline="s49            "> 0f 84 e4 00 00 00      je    401380&nbsp;&lt;main+0x1c1&gt;</span>
<button onclick="aclick('a78','s50')"  >40129c</button><span id="a78"  sline="s50            "> 4c 8b 0b               mov   (%rbx),%r9</span>
<button onclick="aclick('a79','s51')"  >40129f</button><span id="a79"  sline="s51 s52        "> 41 0f b6 01            movzbl(%r9),%eax</span>
<button onclick="aclick('a80','s52')"  >4012a3</button><span id="a80"  sline="s52            "> 3c 30                  cmp   $0x30,%al</span>
<button onclick="aclick('a81','s52')"  >4012a5</button><span id="a81"  sline="s52            "> 0f 84 76 ff ff ff      je    401221&nbsp;&lt;main+0x62&gt;</span>
<button onclick="aclick('a82','s52')"  >4012ab</button><span id="a82"  sline="s52            "> 3c 78                  cmp   $0x78,%al</span>
<button onclick="aclick('a83','s52')"  >4012ad</button><span id="a83"  sline="s52            "> 74 88                  je    401237&nbsp;&lt;main+0x78&gt;</span>
<button onclick="aclick('a84','s52')"  >4012af</button><span id="a84"  sline="s52            "> 4c 89 ce               mov   %r9,%rsi</span>
<button onclick="aclick('a85','s52')"  >4012b2</button><span id="a85"  sline="s52            "> b9 0a 00 00 00         mov   $0xa,%ecx</span>
<button onclick="aclick('a86','s68')"  >4012b7</button><span id="a86"  sline="s68            "> 4c 8b 45 00            mov   0x0(%rbp),%r8</span>
<button onclick="aclick('a87','s68')"  >4012bb</button><span id="a87"  sline="s68            "> bf 00 00 00 00         mov   $0x0,%edi</span>
<button onclick="aclick('a88','s68')"  >4012c0</button><span id="a88"  sline="s68            "> eb 99                  jmp   40125b&nbsp;&lt;main+0x9c&gt;</span>
<button onclick="aclick('a89','s68')"  >4012c2</button><span id="a89"  sline="s68 s81        "> bf 28 20 40 00         mov   $0x402028,%edi</span>
<button onclick="aclick('a90','s81')"  >4012c7</button><span id="a90"  sline="s81            "> b8 00 00 00 00         mov   $0x0,%eax</span>
<button onclick="aclick('a91','s81')"  >4012cc</button><span id="a91"  sline="s81            "> e8 5f fd ff ff         call  401030&nbsp;&lt;printf@plt&gt;</span>
<button onclick="aclick('a92','s82')"  >4012d1</button><span id="a92"  sline="s82            "> bf 01 00 00 00         mov   $0x1,%edi</span>
<button onclick="aclick('a93','s82')"  >4012d6</button><span id="a93"  sline="s82            "> e8 a5 fd ff ff         call  401080&nbsp;&lt;exit@plt&gt;</span>
<button onclick="aclick('a94','s87')"  >4012db</button><span id="a94"  sline="s87            "> 4c 89 ce               mov   %r9,%rsi</span>
<button onclick="aclick('a95','s87')"  >4012de</button><span id="a95"  sline="s87            "> bf 2f 20 40 00         mov   $0x40202f,%edi</span>
<button onclick="aclick('a96','s87')"  >4012e3</button><span id="a96"  sline="s87            "> b8 00 00 00 00         mov   $0x0,%eax</span>
<button onclick="aclick('a97','s87')"  >4012e8</button><span id="a97"  sline="s87            "> e8 43 fd ff ff         call  401030&nbsp;&lt;printf@plt&gt;</span>
<button onclick="aclick('a98','s87')"  >4012ed</button><span id="a98"  sline="s87            "> eb a0                  jmp   40128f&nbsp;&lt;main+0xd0&gt;</span>
<button onclick="aclick('a99','s87')"  >4012ef</button><span id="a99"  sline="s87 s91        "> 48 8d 5c 24 40         lea   0x40(%rsp),%rbx</span>
<button onclick="aclick('a100','s87')" >4012f4</button><span id="a100" sline="s91            "> 48 89 de               mov   %rbx,%rsi</span>
<button onclick="aclick('a101','s91')" >4012f7</button><span id="a101" sline="s91            "> bf 02 00 00 00         mov   $0x2,%edi</span>
<button onclick="aclick('a102','s91')" >4012fc</button><span id="a102" sline="s91            "> e8 5f fd ff ff         call  401060&nbsp;&lt;tcgetattr@plt&gt;</span>
<button onclick="aclick('a103','s92')" >401301</button><span id="a103" sline="s92            "> 48 89 e7               mov   %rsp,%rdi</span>
<button onclick="aclick('a104','s92')" >401304</button><span id="a104" sline="s92            "> b9 0f 00 00 00         mov   $0xf,%ecx</span>
<button onclick="aclick('a105','s92')" >401309</button><span id="a105" sline="s92            "> 48 89 de               mov   %rbx,%rsi</span>
<button onclick="aclick('a106','s92')" >40130c</button><span id="a106" sline="s92            "> f3 a5                  rep&nbsp;movsl%ds:(%rsi),%es:(%rdi)</span>
<button onclick="aclick('a107','s93')" >40130e</button><span id="a107" sline="s93            "> 48 89 e7               mov   %rsp,%rdi</span>
<button onclick="aclick('a108','s93')" >401311</button><span id="a108" sline="s93            "> e8 3a fd ff ff         call  401050&nbsp;&lt;cfmakeraw@plt&gt;</span>
<button onclick="aclick('a109','s95')" >401316</button><span id="a109" sline="s95            "> 48 89 e2               mov   %rsp,%rdx</span>
<button onclick="aclick('a110','s95')" >401319</button><span id="a110" sline="s95            "> be 00 00 00 00         mov   $0x0,%esi</span>
<button onclick="aclick('a111','s95')" >40131e</button><span id="a111" sline="s95            "> bf 02 00 00 00         mov   $0x2,%edi</span>
<button onclick="aclick('a112','s95')" >401323</button><span id="a112" sline="s95            "> e8 48 fd ff ff         call  401070&nbsp;&lt;tcsetattr@plt&gt;</span>
<button onclick="aclick('a113','s43')" >401328</button><span id="a113" sline="s96 s43        "> 41 bc ff ff ff ff      mov   $0xffffffff,%r12d</span>
<button onclick="aclick('a114','s43')" >40132e</button><span id="a114" sline="s43            "> bd ff ff ff ff         mov   $0xffffffff,%ebp</span>
<button onclick="aclick('a115','s96')" >401333</button><span id="a115" sline="s96            "> eb 1d                  jmp   401352&nbsp;&lt;main+0x193&gt;</span>
<button onclick="aclick('a116','s97')" >401335</button><span id="a116" sline="s97 s98 s99    "> 89 df                  mov   %ebx,%edi</span>
<button onclick="aclick('a117','s97')" >401337</button><span id="a117" sline="s99            "> e8 5a fe ff ff         call  401196&nbsp;&lt;show_char&gt;</span>
<button onclick="aclick('a118','s82')" >40133c</button><span id="a118" sline="s100 s82 s84   "> 48 8b 35 3d 31 00 00   mov   0x313d(%rip),%rsi    #&nbsp;404480&nbsp;&lt;stdout@@GLIBC_2.2.5&gt;</span>
<button onclick="aclick('a119','s84')" >401343</button><span id="a119" sline="s84            "> bf 0d 00 00 00         mov   $0xd,%edi</span>
<button onclick="aclick('a120','s84')" >401348</button><span id="a120" sline="s84            "> e8 f3 fc ff ff         call  401040&nbsp;&lt;putc@plt&gt;</span>
<button onclick="aclick('a121','s97')" >40134d</button><span id="a121" sline="s97            "> 41 89 ec               mov   %ebp,%r12d</span>
<button onclick="aclick('a122','s98')" >401350</button><span id="a122" sline="s98            "> 89 dd                  mov   %ebx,%ebp</span>
<button onclick="aclick('a123','s47')" >401352</button><span id="a123" sline="s96 s47 s49    "> 48 8b 3d 37 31 00 00   mov   0x3137(%rip),%rdi    #&nbsp;404490&nbsp;&lt;stdin@@GLIBC_2.2.5&gt;</span>
<button onclick="aclick('a124','s49')" >401359</button><span id="a124" sline="s49            "> e8 32 fd ff ff         call  401090&nbsp;&lt;getc@plt&gt;</span>
<button onclick="aclick('a125','s96')" >40135e</button><span id="a125" sline="s96            "> 83 e0 7f               and   $0x7f,%eax</span>
<button onclick="aclick('a126','s96')" >401361</button><span id="a126" sline="s96            "> 89 c3                  mov   %eax,%ebx</span>
<button onclick="aclick('a127','s96')" >401363</button><span id="a127" sline="s96            "> 41 39 c4               cmp   %eax,%r12d</span>
<button onclick="aclick('a128','s96')" >401366</button><span id="a128" sline="s96            "> 75 cd                  jne   401335&nbsp;&lt;main+0x176&gt;</span>
<button onclick="aclick('a129','s96')" >401368</button><span id="a129" sline="s96            "> 39 c5                  cmp   %eax,%ebp</span>
<button onclick="aclick('a130','s96')" >40136a</button><span id="a130" sline="s96            "> 75 c9                  jne   401335&nbsp;&lt;main+0x176&gt;</span>
<button onclick="aclick('a131','s102')">40136c</button><span id="a131" sline="s102           "> 48 8d 54 24 40         lea   0x40(%rsp),%rdx</span>
<button onclick="aclick('a132','s102')">401371</button><span id="a132" sline="s102           "> be 00 00 00 00         mov   $0x0,%esi</span>
<button onclick="aclick('a133','s102')">401376</button><span id="a133" sline="s102           "> bf 02 00 00 00         mov   $0x2,%edi</span>
<button onclick="aclick('a134','s102')">40137b</button><span id="a134" sline="s102           "> e8 f0 fc ff ff         call  401070&nbsp;&lt;tcsetattr@plt&gt;</span>
<button onclick="aclick('a135','s104')">401380</button><span id="a135" sline="s104           "> b8 00 00 00 00         mov   $0x0,%eax</span>
<button onclick="aclick('a136','s104')">401385</button><span id="a136" sline="s104           "> 48 81 c4 88 00 00 00   add   $0x88,%rsp</span>
<button onclick="aclick('a137','s104')">40138c</button><span id="a137" sline="s104           "> 5b                     pop   %rbx</span>
<button onclick="aclick('a138','s104')">40138d</button><span id="a138" sline="s104           "> 5d                     pop   %rbp</span>
<button onclick="aclick('a139','s104')">40138e</button><span id="a139" sline="s104           "> 41 5c                  pop   %r12</span>
<button onclick="aclick('a140','s104')">401390</button><span id="a140" sline="s104           "> 41 5d                  pop   %r13</span>
<button onclick="aclick('a141','s104')">401392</button><span id="a141" sline="s104           "> c3                     ret</span>
</div>
</td>
</tr>
</table>

</body>
</html>
HTML
file.close()
