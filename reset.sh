#!/bin/sh
sudo systemctl stop tendermint.service
sudo systemctl stop planetmint.service

source venv/bin/activate
planetmint drop
tendermint unsafe-reset-all

sudo systemctl start tendermint.service
sudo systemctl start planetmint.service
