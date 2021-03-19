require './funclib.rb'

#-----MAIN------
$debug = 0

output = <<-EOHeader
<head>
<link rel="stylesheet" type="text/css" href="ui.css">
<meta http-equiv="refresh" content="30">
</head>

<body>
<div id="bg" width="925px" height="572px">
<img src="mapbg-v1.png">
<!--header before-->
EOHeader

qt_log='/var/www/html/qtlog'
slab1_path="/slab1"
qt_out = File.open('qt_log', "a+")
qt_out.write(Time.now)

data = Array.new
(1..5).each do |num|
	puts "machine oanmr#{num}" if $debug == 1
	data[num] = retrieve("oanmr#{num}oc")
	output += "<div class =\"morph\">\n"
	output+="<div class=\"machine_name\" id=\"nmr#{num}\">OANMR#{num}</div>
<div class=\"qblock\" id=\"qblock#{num}\">
OANMR#{num}:"
	puts data[num][0][0] if $debug == 1
	if data[num][0][0] != -1 && data[num][1][1] != nil #if nothing goes wrong with retrieve
if data[num][0][2]+data[num][0][3] == 0 # if no jobs at all
	output += " no jobs.\n"
else	
		dql = 0
		nql = 0
		dq_table = String.new
		nq_table = String.new
		data[num][1][1].each do |dq|
			dql += dq[7]
			dq_table += "<tr><td nowrap>#{dq[5]}</td><td nowrap>#{dq[2]}</td><td nowrap>#{dq[8]}</td></tr>\n"
		end
		data[num][1][2].each do |nq|
			nql += nq[7]
			nq_table += "<tr><td nowrap>#{nq[5]}</td><td nowrap>#{nq[2]}</td><td nowrap>#{nq[8]}</td></tr>\n"
		end

if data[num][1][3] # if queue has sth
if data[num][1][3][data[num][1][0]][10] == 1 # if dq
	output += "<table class=\"qtable current_q\" id=\"dq#{num}\"><p>Day queue running: "
	dq_table = "<tr id=\"current\"><td nowrap>#{data[num][1][3][data[num][1][0]][5]}</td><td nowrap>#{data[num][1][3][data[num][1][0]][2]}</td><td nowrap>#{data[num][1][3][data[num][1][0]][8]}</td></tr>\n" + dq_table
	dql += data[num][1][3][data[num][1][0]][7]
else
	output += "<table class=\"qtable\" id=\"dq#{num}\"><p>Day queue: "
end #ifdqrunning
if dql == 0
	output += "empty </p></table>\n"
else
	output += "#{(dql/60).to_s} mins in queue<br>
	Machine estimates to finish in #{data[num][0][2]} mins.</p>
<tr class=\"first_row\"><td nowrap class=\"first_row\">Type</td><td nowrap class=\"first_row\">Name</td><td nowrap class=\"first_row\">Owner</td></tr>\n"
	output += dq_table
	output += "</table>\n"
end #if dq

if data[num][1][3][data[num][1][0]][10] == 0
	output += "<table class=\"qtable current_q\" id=\"nq#{num}\"><p>Night queue running: "
	nq_table = "<tr id=\"current\"><td nowrap>#{data[num][1][3][data[num][1][0]][5]}</td><td nowrap>#{data[num][1][3][data[num][1][0]][2]}</td><td nowrap>#{data[num][1][3][data[num][1][0]][8]}</td></tr>\n" + nq_table
else 
	output += "<table class=\"qtable\" id=\"nq#{num}\"><p>Night queue: "
end #if nqrunning
end # if q (data[num][1][3])

if nql == 0
	output += "empty </p></table>\n"
else
	output += "#{(nql/60).to_i} mins in queue<br>
	Machine estimates to finish in #{data[num][0][3]} mins.</p>
<tr class=\"first_row\"><td nowrap class=\"first_row\">Type</td><td nowrap class=\"first_row\">Name</td><td nowrap class=\"first_row\">Owner</td></tr>\n"
output += nq_table
output += "</table>\n"
end #if nq
end #if any jobs at all
		#puts "my own dq and nq length in min: #{(dql/60).to_i}, #{(nql/60).to_i}"
		begin #histories
		puts "history entries for machine #{num}: #{data[num][2].length}" if $debug == 1
		hist_upd_return = hist_tsv_update("oanmr#{num}_hist", data[num][2]) #ARGMT
		puts "new history entries: #{hist_upd_return[1]} of them" if $debug == 1
		rescue
		puts "sth wrong with history on oanmr#{num}"
		bla = `echo \'OANMR#{num} history error at #{Time.now}\'`
		end
	else
		puts "is not reachable." if $debug == 1
		output += "is not reachable."

	end # if reachable
	puts "====" if $debug == 1
output += "</div>"

if data[num][0][0] == 1
	if  data[num][0][2] + data[num][0][3] != 0
		puts "data[num][0] is #{data[num][0]}" if $debug == 1
		output += "<div class=\"statbox\" id =\"stat#{num}\">OANMR#{num} is busy until: #{data[num][0][1].strftime("%Y-%m-%d %H:%M:%S")}</div>"
	else
		output += "<div class=\"statbox statbox_s\" id =\"stat#{num}\">OANMR#{num} finished all jobs!</div>" #statbox_s for STRONG
	end
else
	output += "<div class=\"statbox statbox_m\" id =\"stat#{num}\">OANMR#{num} is not running.</div>" #statbox_m for malfunctioning
end
output += "</div>"
begin
	qt_out.write("\t#{dql}\t#{data[num][0][2]}\t#{nql}\t#{data[num][0][3]}") # log times
rescue
	qt_out.write("-Trouble logging number #{num}-")
end #log times
end #machine iteration

output += "</div><!--bg-->
<div class=\"upd\">Last updated: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}</div>
<div id=\"samba\">Yi-Chung's OANMROC Dashboard beta v1.3<br>Created with VIM with nostalgia</div>
</body>"

outpath='/var/www/html/nmrstat_new.html'
htmlout = File.open(outpath, "w")
htmlout.puts output
qt_out.write("\n")
qt_out.close
=begin
	htmlextout = File.open("#{slab1_path}/homepage/nmrstat_new.html", "w")
	htmlextout.puts output
	htmlextout.close
rescue
	puts "cannot open slab1!"


=end
