require 'erb'
require 'yaml'
require 'json'
require 'ostruct'

### ---------- Define node data
node_data = '
### MAINNET
- type          : "main"
  machine_type  : "n1-standard-1"
  hdd_size      : "400GB"
  netdata_room  : "b99a57d2-397a-4d9d-9655-3113b1c8ccef"
  command       : "-bootstrap -daemon"
  node_locations: ["europe-west1-b"]

### TESTNET
- type          : "test"
  machine_type  : "g1-small"
  hdd_size      : "60GB"
  netdata_room  : "a9c21a87-65f9-4bd8-86b0-e9de831a597a"
  command       : "-testnet -bootstrap -daemon"
  node_locations: ["europe-west1-b", "us-central1"]
'

### ---------- Parse node data
nodes    = JSON.parse(YAML.load(node_data).to_json, object_class: OpenStruct)
template = ERB.new File.read File.expand_path(File.dirname(__FILE__)) + '/nodes.erb'

### ---------- Save
File.open(File.expand_path(File.dirname(__FILE__)) + '/nodes.yml', 'w') {|f| f.write template.result }
