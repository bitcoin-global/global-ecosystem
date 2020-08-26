require 'erb'
require 'yaml'
require 'json'
require 'ostruct'

### ---------- Infrastructure environment information base on .env/nodes.yml data
def environment_information(environments)
  details = ""
  for environment in environments do
    details += "# Environment #{environment.type}net\n\n"
    details += "Instance name | Public IP | ElectrumX | Explorer | Mining pool\n"
    details += "--- | --- | --- | --- | ---\n"
    for node in environment.servers do
      details += "\`#{environment.type}--#{node.location}\`"
      details += " | [#{node.ip}](#{node.ip})"
      details += " | [electrumx.#{node.location}.#{environment.type}net.bitcoin-global.io](electrumx.#{node.location}.#{environment.type}net.bitcoin-global.io)"
      details += " | [explorer.#{node.location}.#{environment.type}net.bitcoin-global.io](https://explorer.#{node.location}.#{environment.type}net.bitcoin-global.io)"
      details += " | [pool.#{node.location}.#{environment.type}net.bitcoin-global.io:#{environment.miner_port}](http://pool.#{node.location}.#{environment.type}net.bitcoin-global.io:#{environment.miner_port})"
      details += "\n"
    end
    details += "\nMain servers (in Europe):\n"
    details += "* **ElectrumX** - [electrumx.#{environment.type}net.bitcoin-global.io](http://electrumx.#{environment.type}net.bitcoin-global.io)\n"
    details += "* **Explorer** - [#{environment.type}net.bitcoin-global.io](https://#{environment.type}net.bitcoin-global.io)\n"
    details += "* **Mining pool** - [pool.#{environment.type}net.bitcoin-global.io:#{environment.miner_port}](http://pool.#{environment.type}net.bitcoin-global.io:#{environment.miner_port})\n"
    details += "\n\n\`Note\` - All **ElectrumX** servers exposed publicly on SSL ports on \`{50001, 50002, 51001, 51002}\`"

    details += "\n\n---\n\n"
  end
  # Return data
  details
end

### ---------- Configs
env_config_file = File.expand_path(File.dirname(__FILE__) + "../../../../") + '/.env/nodes.yml'
net_config      = JSON.parse(YAML.load_file(env_config_file).to_json, object_class: OpenStruct)
env_report      = environment_information(net_config)
operations      = JSON.parse(YAML.load('
- id: deploy
  name: deploy-bootstrap
- id: update
  name: deploy-latest
- id: restart
  name: restart-nodes
- id: electrum
  name: electrum
- id: explorer
  name: explorer
- id: miner
  name: miner
- id: shared
  name: shared_operations
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
