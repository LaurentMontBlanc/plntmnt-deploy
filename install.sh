#!/bin/bash

sudo apt install -y mongodb
wget https://github.com/tendermint/tendermint/releases/download/v0.34.15/tendermint_0.34.15_linux_amd64.tar.gz
tar zxf tendermint_0.34.15_linux_amd64.tar.gz
rm tendermint_0.34.15_linux_amd64.tar.gz *.md LICENSE
sudo mv tendermint /usr/local/bin
/usr/local/bin/tendermint init


sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt-get update
sudo apt-get install -y python3.9 python3.9-dev 
sudo apt-get update
sudo apt-get install -y python3-virtualenv

virtualenv -p /usr/bin/python3.9 venv
source venv/bin/activate

pip install planetmint

planetmint -y configure
sed -i -e 's/localhost:9984/0\.0\.0\.0:9984/g' .planetmint


wget https://gist.githubusercontent.com/eckelj/c23169246db58cdd985c36148dd9469d/raw/ca0a4a77b64f36b84858114c43781da189764325/planetmint.service
wget https://gist.githubusercontent.com/eckelj/00f994ba1ad92349ed8c07ad9f27b1d4/raw/eae794ceb7b158541192f1b1e707824e83a916d3/tendermint.service
sudo cp planetmint.service /etc/systemd/system/
sudo cp tendermint.service /etc/systemd/system/
sudo rm planetmint.service
sudo rm tendermint.service

sudo systemctl daemon-reload
sudo systemctl start planetmint.service
sudo systemctl enable planetmint.service
sudo systemctl start tendermint.service
sudo systemctl enable tendermint.service
