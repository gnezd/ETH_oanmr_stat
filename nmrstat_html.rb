require 'net/http'
require 'uri'

def login(machine_name, debug = nil)
	u=URI('http://'+machine_name+'.ethz.ch:8015/template-login.html') #aim login page
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

def retrieve(machine_name)
begin
	sock, session = login(machine_name)	
	#stat
	
	stat = get_page(sock, session, '/template-status.htm').split(/arrow\.gif.*>/)[1].split(/\s{3,}|</)[1] #chop off headder, cleave off all html tags and the large white space before the stat string
	#holdertable = get_page(sock, session, '/template-holdertable.htm').split(/id=\"DataTable\">|<\/table>/)[1].split(/<\/tr>\n<tr.*>\n|<tr.*>\n/).drop(1)
	#history
	#history = get_page(sock, session, '/template-history.htm').split(/id=\"DataTable\">|<\/table>/)[1].split(/<\/tr>\n<tr.*>\n|<tr.*>\n/).drop(1)
	#return stat, holdertable, history
rescue
	stat = "#{machine_name} cannot be reached"
end
	return stat, 0, 0 #simplify the current version: just get the stats

end
#-----MAIN------
#data3 = retrieve('oanmr3oc')
output = String.new #here starts a very ugly buffer-output approach
			#will be rewritten to do both STDIO and html dump at the same time using a single function

output << '<head><meta http-equiv="refresh" content="30"></head>'
output << "\n"
output << '<body><font size="5" face="verdana">'
output << "<p>Try the new beta-v1 version <a href=\"nmrstat_new.html\">HERE!</a></p>"
output << "\n"

data = Array.new
(1..5).each do |num|
	puts num
	if num == 100 
		output << "<p><b>oanmr3oc: Skipped for now</b><br>"
		
	else
	data[num] = retrieve("oanmr#{num}oc")
	data[num]
	output << "<p><b>oanmr#{num}oc:</b><br>"
	output << data[num][0]
	output << "<br>-----</p>\n"
	end
end

output << "<p>Last updated:#{Time.now}</p>\n"
output << "</font></body>\n"

outpath='/var/www/html/nmrstat.html'
htmlextout = File.open('/home/pi/slab1/homepage/nmrstat.html', "w")
htmlout = File.open(outpath, "w")
htmlextout.puts output
htmlout.puts output
puts output

