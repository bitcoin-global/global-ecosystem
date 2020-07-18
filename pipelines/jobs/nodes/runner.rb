require 'erb'
require 'yaml'
require 'json'
require 'ostruct'

### ---------- Configs
env_config_file = File.expand_path(File.dirname(__FILE__) + "../../../../") + '/.env/nodes.yml'
net_config      = JSON.parse(YAML.load_file(env_config_file).to_json, object_class: OpenStruct)
operations      = JSON.parse(YAML.load('
- id: deploy
  name: deploy-nodes
- id: stop
  name: stop-nodes
- id: update
  name: update-nodes
- id: electrum
  name: configure-electrum
- id: explorer
  name: configure-explorer
').to_json, object_class: OpenStruct)

### ---------- Parse node data
for operation in operations do
  # Create pipeline files
  node_operation = ERB.new File.read File.expand_path(File.dirname(__FILE__)) + '/node.erb'
  File.open(File.expand_path(File.dirname(__FILE__)) + '/ignore.nodes.yml', 'w') {|f| f.write node_operation.result }

  pipeline = ERB.new File.read File.expand_path(File.dirname(__FILE__)) + '/pipeline.erb'
  File.open(File.expand_path(File.dirname(__FILE__) + "../../../") + '/ignore.nodes.pipeline.yml', 'w') {|f| f.write pipeline.result }

  # Perform concourse upgrade
  command = "aviator -f " + (File.expand_path(File.dirname(__FILE__) + "../../../") + '/ignore.nodes.pipeline.yml')
  puts command
  system(command)
end

# Run file cleanup
puts "Running cleanup"
system('rm -rf ' + File.expand_path(File.dirname(__FILE__)) + '/ignore.nodes.yml')
system('rm -rf ' + File.expand_path(File.dirname(__FILE__) + "../../../") + '/ignore.nodes*.pipeline.yml')
