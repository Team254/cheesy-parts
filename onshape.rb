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
    if x["name"] == 'Main'
      return x['id']
    end
  end
end

def onshape_getchildren(assydef)
  res = {}
  for x in assydef["rootAssembly"]["instances"]
    obj = {}
    obj["name"] = x["name"]
    obj["type"] = x["type"]
    obj["documentId"] = x["documentId"]
    obj["elementId"] = x["elementId"]
    obj["quantity"] = 1

    uid = x["elementId"]
    if x.key?("partId")
      uid = uid + x["partId"]
      obj["partId"] = x["partId"]
    end

    # Bump quantity if already in tree
    if res.key?(uid)
      res[uid]["quantity"] += 1

    # Otherwise add to tree
    else
      unless x.key?("partId")
        workspace = onshape_mainworkspace(x["documentId"])
        assydef2 = onshape_request('/api/assemblies/d/'+x["documentId"]+'/w/'+workspace+'/e/'+x["elementId"])
        obj["children"] = onshape_getchildren(assydef2)
      end
      res[uid] = obj
    end

  end
  return res
end

def onshape_assemblytree(project)
  document = project.onshape_top_document
  element = project.onshape_top_element
  workspace = onshape_mainworkspace(document)

  assydef = onshape_request("/api/assemblies/d/"+document+"/w/"+workspace+"/e/"+element)
  tree = {}
  tree["type"] = "Assembly"
  tree["documentId"] = document
  tree["elementId"] = element
  tree["workspaceId"] = workspace
  tree["children"] = onshape_getchildren(assydef)

  print tree.to_json
end

for project in Project.all
  unless project.onshape_top_document.to_s.strip.empty?
    onshape_assemblytree(project)
  end
end