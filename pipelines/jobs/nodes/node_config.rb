require 'erb'
require 'yaml'
require 'json'
require 'ostruct'

### ---------- Define node data
node_data = '
### MAINNET
- type          : "main"
  machine_type  : "g1-small"
  hdd_size      : "400GB"
  netdata_room  : "b99a57d2-397a-4d9d-9655-3113b1c8ccef"
  command       : "-bootstrap -daemon"
  node_locations: 
  - us-central1-a
  - southamerica-east1-b
  - asia-east2-a
  - asia-south1-c
  - australia-southeast1-b
  - europe-west1-b

### TESTNET
- type          : "test"
  machine_type  : "f1-micro"
  hdd_size      : "60GB"
  netdata_room  : "a9c21a87-65f9-4bd8-86b0-e9de831a597a"
  command       : "-testnet -bootstrap -daemon"
  node_locations: 
  - us-central1-a
  - europe-west1-b
'

### ---------- Parse node data
nodes  = JSON.parse(YAML.load(node_data).to_json, object_class: OpenStruct)
start = ERB.new File.read File.expand_path(File.dirname(__FILE__)) + '/start.erb'
stop   = ERB.new File.read File.expand_path(File.dirname(__FILE__)) + '/stop.erb'

### ---------- Save
File.open(File.expand_path(File.dirname(__FILE__)) + '/ignore.nodes-start.yml', 'w') {|f| f.write start.result }
File.open(File.expand_path(File.dirname(__FILE__)) + '/ignore.nodes-stop.yml', 'w') {|f| f.write stop.result }
