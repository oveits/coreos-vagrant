# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'

Vagrant.require_version ">= 1.6.0"

CLOUD_CONFIG_PATH = File.join(File.dirname(__FILE__), "user-data")
SSHAGENT_CONFIG_PATH = File.join(File.dirname(__FILE__), "provision_ssh_agent_bashrc.sh")
CONFIG = File.join(File.dirname(__FILE__), "config.rb")
INSECURE_KEY_PATH = "#{ENV['USERPROFILE']}/.vagrant.d/insecure_private_key" 

# Defaults for config options defined in CONFIG
$num_instances = 1
$instance_name_prefix = "core"
$update_channel = "alpha"
$image_version = "current"
$enable_serial_logging = false
$share_home = false
$vm_gui = false
$vm_memory = 1024
$vm_cpus = 1
$shared_folders = {}
$forwarded_ports = {}

# Attempt to apply the deprecated environment variable NUM_INSTANCES to
# $num_instances while allowing config.rb to override it
if ENV["NUM_INSTANCES"].to_i > 0 && ENV["NUM_INSTANCES"]
  $num_instances = ENV["NUM_INSTANCES"].to_i
end

if File.exist?(CONFIG)
  require CONFIG
end

# Use old vb_xxx config variables when set
def vm_gui
  $vb_gui.nil? ? $vm_gui : $vb_gui
end

def vm_memory
  $vb_memory.nil? ? $vm_memory : $vb_memory
end

def vm_cpus
  $vb_cpus.nil? ? $vm_cpus : $vb_cpus
end

Vagrant.configure("2") do |config|
  # add HTTP proxy configuration (uncomment, if you have installed the vagrant proxy plugin; 
  # note that the vagrant proxy plugin must be fixed as described on https://github.com/tmatilai/vagrant-proxyconf/issues/123, 
  # i.e. you need to replace "tmp" by "tmp_file" in $USERPROFILE/.vagrant.d/gems/gems/vagrant-proxyconf-1.5.0/lib/vagrant-proxyconf/cap/coreos/docker_proxy_conf.rb
  # uncomment, if you have implemented the workaround above and you want to make use of the vagrant proxy plugin:
#  if Vagrant.has_plugin?("vagrant-proxyconf")
#    config.proxy.http     = "http://proxy.example.com:8080/"
#    config.proxy.https    = "http://proxy.example.com:8080/"
#    config.proxy.no_proxy = "localhost,127.0.0.1,.example.com"
#  end

  # make sure the ssh agent is started, using the insecure private key 
  # note: for now, the private key is assumed to be uploaded

  #config.vm.provision :shell, :path => "provision_ssh_agent.sh", :privileged => true
  #config.vm.provision :shell, :inline => "echo ierhgieh > /tmp/ierhgieh", :privileged => true


  # always use Vagrants insecure key
  config.ssh.insert_key = false

  config.vm.box = "coreos-%s" % $update_channel
  if $image_version != "current"
      config.vm.box_version = $image_version
  end
  config.vm.box_url = "http://%s.release.core-os.net/amd64-usr/%s/coreos_production_vagrant.json" % [$update_channel, $image_version]

  ["vmware_fusion", "vmware_workstation"].each do |vmware|
    config.vm.provider vmware do |v, override|
      override.vm.box_url = "http://%s.release.core-os.net/amd64-usr/%s/coreos_production_vagrant_vmware_fusion.json" % [$update_channel, $image_version]
    end
  end

  config.vm.provider :virtualbox do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.functional_vboxsf     = false
  end

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  (1..$num_instances).each do |i|
    config.vm.define vm_name = "%s-%02d" % [$instance_name_prefix, i] do |config|
      config.vm.hostname = vm_name

      if $enable_serial_logging
        logdir = File.join(File.dirname(__FILE__), "log")
        FileUtils.mkdir_p(logdir)

        serialFile = File.join(logdir, "%s-serial.txt" % vm_name)
        FileUtils.touch(serialFile)

        ["vmware_fusion", "vmware_workstation"].each do |vmware|
          config.vm.provider vmware do |v, override|
            v.vmx["serial0.present"] = "TRUE"
            v.vmx["serial0.fileType"] = "file"
            v.vmx["serial0.fileName"] = serialFile
            v.vmx["serial0.tryNoRxLoss"] = "FALSE"
          end
        end

        config.vm.provider :virtualbox do |vb, override|
          vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
          vb.customize ["modifyvm", :id, "--uartmode1", serialFile]
        end
      end

      if $expose_docker_tcp
        config.vm.network "forwarded_port", guest: 2375, host: ($expose_docker_tcp + i - 1), auto_correct: true
      end

      $forwarded_ports.each do |guest, host|
        config.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
      end

      ["vmware_fusion", "vmware_workstation"].each do |vmware|
        config.vm.provider vmware do |v|
          v.gui = vm_gui
          v.vmx['memsize'] = vm_memory
          v.vmx['numvcpus'] = vm_cpus
        end
      end

      config.vm.provider :virtualbox do |vb|
        vb.gui = vm_gui
        vb.memory = vm_memory
        vb.cpus = vm_cpus
      end

      ip = "172.17.8.#{i+100}"
      config.vm.network :private_network, ip: ip

      # Uncomment below to enable NFS for sharing the host machine into the coreos-vagrant VM.
      #config.vm.synced_folder ".", "/home/core/share", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      $shared_folders.each_with_index do |(host_folder, guest_folder), index|
        config.vm.synced_folder host_folder.to_s, guest_folder.to_s, id: "core-share%02d" % index, nfs: true, mount_options: ['nolock,vers=3,udp']
      end

      if $share_home
        config.vm.synced_folder ENV['HOME'], ENV['HOME'], id: "home", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      end

      if File.exist?(CLOUD_CONFIG_PATH)
        config.vm.provision :file, :source => "#{CLOUD_CONFIG_PATH}", :destination => "/tmp/vagrantfile-user-data"
        config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end

      #logger = Vagrant::Logger.new(STDOUT)
      if !ENV["USERPROFILE"].nil? && File.exist?(INSECURE_KEY_PATH)
        p "copying insecure SSH key from #{INSECURE_KEY_PATH}"
	#logger.info("Copying insecure SSH key from #{INSECURE_KEY_PATH}")
        config.vm.provision :file, :source => "#{INSECURE_KEY_PATH}", :destination => "~core/.ssh/insecure_private_key"
	config.vm.provision :shell, :inline => "chown core ~core/.ssh/insecure_private_key; chmod 600 ~core/.ssh/insecure_private_key"
      end

      if File.exist?(SSHAGENT_CONFIG_PATH)
  	config.vm.provision :file, :source => "#{SSHAGENT_CONFIG_PATH}", :destination => "/tmp/vagrantfile-ssh_agent_bashrc"
  	config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-ssh_agent_bashrc /var/lib/coreos-vagrant/", :privileged => true
	config.vm.provision :shell, :inline => "[ -L ~core/.bashrc.orig ] || mv ~core/.bashrc ~core/.bashrc.orig; cp /usr/share/skel/.bashrc ~core/.bashrc; echo '[ -r /var/lib/coreos-vagrant/vagrantfile-ssh_agent_bashrc ] && . /var/lib/coreos-vagrant/vagrantfile-ssh_agent_bashrc' >> ~core/.bashrc", :privileged => true
      end
  

    end # (1..$num_instances).each do |i|
  end
end
