#!/bin/sh

sudo systemctl stop planetmint.service
sudo systemctl stop tendermint.service

wget https://gist.githubusercontent.com/eckelj/81bd91e391fd0eb96527af87339a41cf/raw/24f5587cc7527bef3224c47e46ccb4a025c9d87a/genesis.yml
cp genesis.yml ~/.tendermint/config/genesis.json
rm genesis.yml

wget https://raw.githubusercontent.com/bigchaindb/BEPs/master/23/config.toml
#wget https://gist.githubusercontent.com/eckelj/2bfd09b869dd8fc04ce6310f0d458186/raw/80ae7c7c0c2ef4dcdb9467a70e94a08f35a0b1a5/config.toml
cp config.toml ~/.tendermint/config/config.toml
rm config.toml

sudo systemctl start planetmint.service
sudo systemctl start tendermint.service
