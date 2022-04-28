#!/bin/bash

sudo apt remove mongodb
sudo rm /usr/local/bin/tendermint 
rm -rf ~/.tendermint

sudo apt-get remove -y python3.9 python3.9-dev
rm -rf ~/venv
rm ~/.planetmint

sudo systemctl stop planetmint.service
sudo systemctl disable planetmint.service
sudo systemctl stop tendermint.service
sudo systemctl disable tendermint.service
