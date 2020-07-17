require 'erb'
require 'yaml'
require 'json'
require 'ostruct'

### ---------- Configs
env_config_file = File.expand_path(File.dirname(__FILE__) + "../../../../") + '/.env/nodes.yml'
net_config      = JSON.parse(YAML.load_file(env_config_file).to_json, object_class: OpenStruct)
operations      = ["deploy", "stop", "update", "shared"]

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
