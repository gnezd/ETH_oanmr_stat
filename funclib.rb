require 'net/http'
require 'uri'
require 'time'

def login(machine_name, debug = nil)
	u=URI('http://'+machine_name+'.ethz.ch:8015/template-login.html') #aim login page #ARGMT
	req=Net::HTTP::Get.new(u.path)
	sock=Net::HTTP.new(u.host, u.port)
	begin
	res=sock.request(req)
	session=res.header['set-cookie'] #read session cookie
	puts "cookie1:#{session}" if debug == 1

	req2=Net::HTTP::Post.new(URI(res.header['location']).path) #get redirection
	req2.add_field 'cookie', session
	req2.add_field 'user-agent', 'Mozilla'
	req2.set_form_data('salts' => 'wi', 'username1' => 'bdzeng', 'group' => 'login','login' => 'Login', 'salt_wi'=> '', 'username' => 'bdzeng')
	res=sock.request(req2) #login
	brief('req2', res, 1) if debug == 1

	req3=Net::HTTP::Get.new(URI(res.header['location']).path)
	req3.add_field 'cookie', session
	req3.add_field 'user-agent', 'Mozilla'
	res=sock.request(req3)
	brief('req3', res, 1) if debug ==1

	return sock, session
	rescue
		return 0, 0
	end


end

def brief(name ,p_res, mode) #pass in a page query result and make a report
	puts "#{name}:"
	puts "code: #{p_res.code}"
	if mode==1 
		p_res.header.each_header {|key, value| puts "#{key} - #{value}"}
	end
	puts "redirection: going to #{p_res.header['location']}" if p_res.header['location']
	puts '-----'
end

def exp_table_form(holdertable, num, debug = nil)
	registered_exp = Array.new
	running_exp = 0
	puts "exp_table_form called for machine #{num}" if debug == 1
(0..holdertable.length-1).each do |line_n|
	table_line_parsed = holdertable[line_n].split(/(?:<td[^<>]*>)|(?:<\/td>\n<td[^<>]*>)|(?:<\/td>\n?)/)
	if num < 3
		#fucking machine 1 and 2 with the "analysis" field
		#2019 Jul 01 edit
		table_line_parsed.delete_at(9)
	end
		if table_line_parsed[5] != '&nbsp;' && table_line_parsed[5]!='' #not the stupid holder number row
	#start parsing
			packed_exp = Array.new #temp arr for table content translation. Important to re-init this!
			packed_exp[0] = table_line_parsed[1].split('checkbox">')[1].to_i	#holder #
		case table_line_parsed[4]
		when /Completed/
			packed_exp[1] = 1
		when /Queued/
			packed_exp[1] = 2
		when /Running/
			packed_exp[1] = 0
			running_exp = registered_exp.length
		else
			packed_exp[1] = -1
		end	#State
			packed_exp[2] = table_line_parsed[5]	#file name
			packed_exp[3] = table_line_parsed[6].to_i	#exp number
			packed_exp[4] = table_line_parsed[7]	#solvent
			packed_exp[5] = table_line_parsed[8]	#experiment type
			if table_line_parsed[10] =~ /</	#if the name is too long and Bruker-smart-ass decided to shorten it
		packed_exp[6] = table_line_parsed[10].split(/(?:title=")|(">\s)/)[1].gsub(/[\r\n]+/, ' ') # then carve out the sample name from the hover text
			else
		packed_exp[6] = table_line_parsed[10].gsub(/\n/, " ")	#otherwise simply copy and squeeze
			end
			(hh, mm, ss) = table_line_parsed[13].split(':')	#exp duration into seconds
			packed_exp[7] = 3600*hh.to_i + 60*mm.to_i + ss.to_i
			packed_exp[8] = table_line_parsed[14]	#exp owner
		if table_line_parsed[15] =~ /\d\d:\d\d\s\w\w\w\s\w\w\w\s\d\d\s\d\d\d\d/ #exp start time if given
			(hour, min, wday, month, day, year) = table_line_parsed[15].split(/\s|:/)
			packed_exp[9] = Time.new(year, month, day, hour, min)
		else
			packed_exp[9] = ''
		end
			packed_exp[10] = case table_line_parsed[11] 
			when /sun\.gif/
				1
			when /moon.gif/
		 		0
			else
	 			-1
			end
			registered_exp.push(packed_exp)
		end	#registered sample
	end	#each line
	puts "exp_table_form_complete, returning registered_exp with number of #{registered_exp.size}" if debug == 1
	return registered_exp
end

def get_page(sock, session, page)
	begin
		req = Net::HTTP::Get.new(page)
		req.add_field 'cookie', session
		res = sock.request(req)
		return res.body
	rescue
		return -1
	end

end

def cnq(holdertable, num = nil, debug = nil)
	puts "entering cnq" if debug ==1
	exps = Array.new
	exps = exp_table_form(holdertable, num, debug)
	puts "survived exp_table_form return" if debug == 1
	current = -1
	nq = Array.new
	dq = Array.new
	puts "cnq begin. exp table #{exps.size} lines brought in" if debug == 1
	(0..exps.length-1).each do |n|
		case exps[n][1]
		when 0
			current = n.to_i
			puts "current job is #{n}" if debug == 1
		when 2
		if exps[n][10] == 1 #day Q
			dq.push(exps[n])
		end
		if exps[n][10] == 0
			nq.push(exps[n])
		end
		else
		end
#----
	if dq == nil
		puts "dqnil"
	else
		#puts "dqsorting"
		dq.sort! {|a,b| a[9] <=> b[9]}
	end
		if nq == nil
		puts "nqnil"
	else
		#puts "nqsorting"
		nq.sort! {|a,b| a[9] <=> b[9]}
	end
#---


	end
	return current, dq, nq, exps
end

def holdertable_html_parse(html, num = nil, debug = nil)
	holdertable = Array.new
	holdertable = html.split(/(?:id=\"DataTable\">)|(?:<\/table>)/)[1].split(/(?:<\/tr>\n<tr.*>\n)|(?:<tr.*>\n)|(?:<\/tr>)/).drop(1)
	holdertable.pop(2)
	puts "ready for cnq call of #{holdertable.length} lines of #{holdertable.class}" if debug == 1
	return cnq(holdertable, num, debug)
end

def typ_adj(hist_line)
	hist_line_f = Array.new
	hist_line_f[0] = Time.parse(hist_line[0])
	hist_line_f[1] = hist_line[1].to_i
	hist_line_f[2] = hist_line[2]
	hist_line_f[3] = hist_line[3].to_i
	hist_line_f[4] = hist_line[4]
	hist_line_f[5] = hist_line[5].to_i
	hist_line_f[6] = hist_line[6].to_i
	hist_line_f[7] = hist_line[7].to_i
	hist_line_f[8] = hist_line[8].to_i
	hist_line_f[9] = hist_line[9].to_i
	hist_line_f[10] = hist_line[10].to_i
	hist_line_f[11] = hist_line[11].to_i
	hist_line_f[12..14] = hist_line[12..15]
	return hist_line_f
end

def hist_tsv_parse(tsvln)
	line_parsed = typ_adj(tsvln.split(/(?:^')|(?:'\t')|(?:'\t$)/).drop(1))
	return line_parsed
end

def hist_tsv_form(hist_form)
	output = String.new
	hist_form.each do |col|
		output << "'#{col}'\t"
	end
	output << "\n"
	return output
end

def hist_html_parse(html, v_oder_f = nil)
	tablelines = html.split(/(?:<table[^<>]+\sid="DataTable">)|(?:<\/table>)/)[1].split(/(?:<\/tr>\W+(?:<tr[^>]+>\W*\n))|(?:<tr[^>]+>\n)|(?:<\/tr>)/)
	parsed = Array.new
	tablelines[1..tablelines.length-3].each do |ln|
		lineparsed = Array.new
		lineparsed = ln.split(/(?:(?:<\/td>\n)?<td[^>]+>)|(?:<\/td>)/).drop(1)
		#if v_oder_f != nil
		lineparsed = lineparsed.drop(1)
		#puts "v or f! #{lineparsed[1]}|#{lineparsed[2]}"
		#end
		lineparsed.pop
		line_form = Array.new	
		line_form[0] = Time.parse(lineparsed[0] + ' ' + lineparsed[1])
		line_form[1] = lineparsed[2].to_i
		line_form[2] = lineparsed[3]
		line_form[3] = lineparsed[4].to_i
		line_form[4] = lineparsed[5]
		line_form[5..11] = [0, 0, 0, 0, 0, 0, 0]
=begin
		line_form[5] += 1 if lineparsed[6] =~ /haken\.gif/ #load
		line_form[6] += 1 if lineparsed[7] =~ /haken\.gif/ #
		line_form[7] += 1 if lineparsed[8] =~ /haken\.gif/
		line_form[8] += 1 if lineparsed[9] =~ /haken\.gif/
		line_form[9] += 1 if lineparsed[10] =~ /haken\.gif/
		line_form[10] += 1 if lineparsed[11] =~ /haken\.gif/
		line_form[11] += 1 if lineparsed[12] =~ /haken\.gif/
=end 28 Feb 2019
		(5..11).each do |c|
			if lineparsed[c+1] =~ /haken/
				line_form[c] = 1
			elsif lineparsed[c+1] =~ /error/
				line_form[c] = -1
			else
				line_form[c] = 0
			end
		end

		line_form[12..14] = lineparsed[13..15]
		if line_form[14] == nil || line_form[14] == ''
			line_form[14] = ' '
		end
		parsed.push(line_form)
	end
	return parsed
end

def hist_tsv_update(filename, parsed, debug = nil)
	output = String.new
	last_hist = Array.new
	tsvlines = Array.new
	orig = String.new
	tsv = File.open(filename, "a+")
	tsvlines = tsv.readlines
	if tsvlines.length != 0
		puts "tsvarch read, having #{tsvlines.length} lines" if debug == 1
		last_hist = hist_tsv_parse(tsvlines[0])
		puts "last entry: #{last_hist[2]} at #{last_hist[0]}" if debug == 1
		tsvlines.each do |ln|
			orig << ln
		end
	else
		puts "empty file, set time at 1990" if debug == 1
		last_hist[0] = Time.new(1990)
	end
	#check time
	newer_meas = Array.new
	parsed.each do |meas|
		if meas[0] > last_hist[0] && meas[10] != 0 #28 Feb 1224 added the second crit: don't push if not yet measured
			newer_meas.push(meas)
		else
		end
	end
	puts "new entries: #{newer_meas.length}" if debug == 1
	newer_meas.each do |meas|
		output << hist_tsv_form(meas)
	end
	if output != ''
		puts "some new output, close tsv and open to write" if debug == 1
		tsv.close
		tsv = File.open(filename, "w")
		output << orig
		tsv.print(output)
		tsv.close
	end
	return last_hist, newer_meas.length
end

def stat_parse(stat_html, debug = nil)
	if stat_html == -1
		puts "-1 passed into stat_parse" if debug == 1
		return -1, 0, 0, 0
	else
		stat_text = stat_html.split(/arrow\.gif.*>/)[1].split(/(?:^\s{3,})|(?:<)/)[1] #chop off headder, cleave off all html tags and the large white space before the stat string
		puts stat_text if debug == 1
		parsed = stat_text.split(/(?:\s+-\s)|(?:\s:\s)/)
		parsed_form = Array.new
		parsed_form[0] = case parsed[1]
				 when /Running/
					 1
				 when /Stop/
					 0
				 else
					 -1
				 end
		if parsed[3] =~ /No\sJobs/
			parsed_form[1] = Time.now
		else 
			parsed_form[1] = Time.parse(parsed[3])
			puts "#{parsed[3]} -> #{parsed_form[1].strftime("%a %H:%M")}" if debug == 1
			while parsed[3] != parsed_form[1].strftime("%a %H:%M")
				parsed_form[1] += 86400
				puts "#{parsed[3]} -> #{parsed_form[1].strftime("%a %H:%M")}" if debug == 1
			end	#if not today adj day
		end
		dt = parsed[5].split ":"
		if dt[0].to_i >= 0	
			parsed_form[2] = dt[0].to_i * 60 + dt[1].to_i
		else
			parsed_form[2] = dt[0].to_i * 60 - dt[1].to_i
		end
		puts "#{parsed[5]} into #{dt}" if debug == 1
			nt =[0, 0]
		nt = parsed[7].split ":"
		if nt[0].to_i >= 0
			parsed_form[3] = nt[0].to_i * 60 + nt[1].to_i
		else
			parsed_form[3] = nt[0].to_i * 60 - nt[1].to_i
		end
		return parsed_form
	end
end

def retrieve(machine_name, debug = nil)
begin
	#html store
	#history_store = File.open("NMR_stat_htmls/#{machine_name}/history.html", "w")
	#stat_store = File.open("NMR_stat_htmls/#{machine_name}/stat.html", "w")
	#holdertable_store = File.open("NMR_stat_htmls/#{machine_name}/holdertable.html", "w")
	debug = 1
	sock, session = login(machine_name, debug)	
	#stat	
	puts "socket made" if debug == 1
	stat_html = get_page(sock, session, '/template-status.htm')
	stat = stat_parse(stat_html)
	puts "stat got" if debug == 1
	if stat[0] == -1
		return stat, nil, nil
	else
	holder_table_html = get_page(sock, session, '/template-holdertable.htm')
	current_and_q = holdertable_html_parse(holder_table_html, machine_name[5].to_i, debug)
	#history
	history_html = get_page(sock, session, '/template-history.htm')
	history = hist_html_parse(history_html)
	#html store
	#history_store.write(history_html)
	#stat_store.write(stat_html)
	#holdertable_store.write(holder_table_html)


	end
rescue
	stat = [-1, 0, 0, 0]
	current_and_q = Array.new
	history = Array.new
end
	return stat, current_and_q, history #simplify the current version: just get the stats

end
