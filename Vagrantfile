# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.network :private_network, ip: "192.168.33.222"
  config.ssh.insert_key = false

  config.vm.provider :virtualbox do |v|
    v.name = "docker-dev"
    v.memory = 2048
    v.cpus = 2
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--ioapic", "on"]
  end

   config.vm.provision "shell", inline: <<-SHELL
     sudo apt-get update
     sudo apt-get install -y software-properties-common
     sudo apt-add-repository -y ppa:ansible/ansible
     sudo apt-get update
     sudo apt-get install -y ansible git
     echo 127.0.0.1 >> /etc/ansible/hosts
     mkdir -p /ansible-docker
     git clone https://github.com/prodamin/docker-ansible.git /ansible-docker 
     cd /ansible-docker/provisioning && ansible-playbook main.yml -c local
   SHELL


end
