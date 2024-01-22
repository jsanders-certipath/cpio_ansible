#! /bin/bash

sudo apt-add-repository ppa:ansible/ansible -y
sudo apt update && sudo apt install -y ansible awscli