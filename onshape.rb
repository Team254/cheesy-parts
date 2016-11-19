require "bundler/setup"

require "date"
require "securerandom"
require "openssl"
require "Base64"
require "uri"
require "net/https"
require "json"

require "sequel"
require "./db"
require "./models/part"
require "./models/project"

def onshape_request(path, query='')
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
  JSON.parse(response.body)
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

# for project in Project.where('onshape_top_document IS NOT NULL')
#   DB.transaction do

#     Part.where(:project_id => project[:id]).update(:onshape_qty => 0,
#       :onshape_document => nil,
#       :onshape_element => nil,
#       :onshape_workspace => nil,
#       :onshape_part => nil,
#       :onshape_microversion => nil)

#     Part[:part_number => 0, :project_id => project[:id]].update_onshape_assy(project,
#         project[:onshape_top_document],
#         project[:onshape_top_element],
#         onshape_mainworkspace(project[:onshape_top_document]))

#   end
# end