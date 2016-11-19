require "date"
require "securerandom"
require "openssl"
require "Base64"
require "uri"
require "net/https"
require "json"

def onshape_request(path, query='', json=true)
  method = 'get'
  base = "https://cad.onshape.com"
  access = CheesyCommon::Config.onshape_key
  secret = CheesyCommon::Config.onshape_secret

  date = Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT")
  nonce = SecureRandom.hex
  contenttype = "application/json";
  agent = "Cheesy Parts";

  string = method+"\n"+nonce+"\n"+date+"\n"+contenttype+"\n"+path+"\n"+query+"\n";
  hash = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new('sha256'), secret, string.downcase)).strip()
  authkey = "On "+access+":HmacSHA256:"+hash;

  uri = URI.parse(base+path+"?"+query)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  req = Net::HTTP::Get.new(uri.request_uri)
  req.add_field('Date', date)
  req.add_field('Accept', contenttype)
  req.add_field('Content-Type', contenttype)
  req.add_field('User-Agent', agent)
  req.add_field('On-Nonce', nonce)
  req.add_field('Authorization', authkey)

  response = http.request(req)
  if json == true
    raise "Onshape API Error" unless response.code.to_i == 200
    JSON.parse(response.body)
  else
    response.body
  end
end

def onshape_mainworkspace(document)
  res = onshape_request('/api/documents/d/'+document+'/workspaces')
  for x in res
    return x['id'] if x["name"] == 'Main'
  end
end

# Remove Instance Number from Part Name
def onshape_partname(item)
  item["name"].sub(/ +<\d+>/, '')
end

def kg_to_lb(input)
  input * 2.20462
end