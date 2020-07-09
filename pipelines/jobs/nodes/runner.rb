require 'erb'
require 'yaml'
require 'json'
require 'ostruct'

### ---------- Configs
operations = ["deploy", "destroy", "update"]

### ---------- Define node data
nodes = JSON.parse(YAML.load('
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
  command       : "-testnet -skiphardforkibd -bootstrap -daemon"
  node_locations: 
  - us-central1-a
  - europe-west1-b
  - asia-east2-a
'
).to_json, object_class: OpenStruct)

### ---------- Parse node data
for operation in operations do
  node_operation = ERB.new File.read File.expand_path(File.dirname(__FILE__)) + '/node.erb'
  File.open(File.expand_path(File.dirname(__FILE__)) + '/ignore.nodes.yml', 'w') {|f| f.write node_operation.result }

  pipeline = ERB.new File.read File.expand_path(File.dirname(__FILE__)) + '/pipeline.erb'
  File.open(File.expand_path(File.dirname(__FILE__) + "../../../") + '/ignore.nodes.pipeline.yml', 'w') {|f| f.write pipeline.result }
  command = "aviator -f " + (File.expand_path(File.dirname(__FILE__) + "../../../") + '/ignore.nodes.pipeline.yml')
  puts command
  # Launch aviator
  system(command)
  # value = %x[ #{command} ]
end