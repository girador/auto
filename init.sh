#!/bin/bash

threads="${1:-3000}"
rpc="${2:-2000}"

cd ~
sudo rm -rf auto || true
git clone https://github.com/girador/auto

#Just in case kill previous copy of mhddos_proxy
sudo pkill -f runner.sh
sudo pkill -f runner.py
sudo pkill -f ./start.py

sudo apt update -y
sudo apt upgrade -y
# Install git, python3
sudo apt install git gcc libc-dev libffi-dev libssl-dev python3-dev rustc -y
sudo apt install git -y
sudo apt upgrade git -y
sudo apt install wget -y
sudo apt upgrade wget -y
sudo apt install python3 -y
sudo apt upgrade python3 -y
sudo apt install python3-pip -y
sudo apt upgrade python3-pip -y
sudo apt install screen -y
sudo apt upgrade screen -y
sudo apt install curl -y
sudo apt upgrade curl -y
sudo -H pip3 install --upgrade pip
ulimit -n 1048576

#Install latest version of mhddos_proxy and MHDDoS
cd ~
sudo rm -r mhddos_proxy
git clone https://github.com/porthole-ascend-cinnamon/mhddos_proxy.git
cd ~/mhddos_proxy
sudo pip3 install -r requirements.txt

sleep 2m

cd ~/auto

screen -dmS "mhddos" bash runner.sh 1 $threads $rpc