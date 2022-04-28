.PHONY: help install start stop logs reset clean

.DEFAULT_GOAL := help


#############################
# Open a URL in the browser #
#############################
define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT


##################################
# Display help for this makefile #
##################################
define PRINT_HELP_PYSCRIPT
import re, sys

print("Planetmint 2.0 developer toolbox")
print("--------------------------------")
print("Usage:  make COMMAND")
print("")
print("Commands:")
for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("    %-16s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT


IS_DOCKER_COMPOSE_INSTALLED := $(shell command -v docker-compose 2> /dev/null)

################
# Main targets #
################

help: ## Show this help
	@$(HELP) < $(MAKEFILE_LIST)

run: check-deps ## Run Planetmint from source (stop it with ctrl+c)
	# although planetmint has tendermint and mongodb in depends_on,
	# launch them first otherwise tendermint will get stuck upon sending yet another log
	# due to some docker-compose issue; does not happen when containers are run as daemons
	@$(DC) up --no-deps mongodb tendermint planetmint

install: check-deps ## Run Planetmint from source and daemonize it (stop with `make stop`)
	@$(DC) up -d planetmint

clean: reset ## Remove all build, test, coverage and Python artifacts

reset: stop clean-states start ## Stop and REMOVE all containers. WARNING: you will LOSE all data stored in Planetmint.

reload: stop start
stop:
	sudo systemctl stop tendermint.service
	sudo systemctl stop planetmint.service
start:
	sudo systemctl start tendermint.service
	sudo systemctl start planetmint.service
configure: stop copy-config start

###############
# Sub targets #
###############
copy-config:
	wget https://gist.githubusercontent.com/eckelj/81bd91e391fd0eb96527af87339a41cf/raw/24f5587cc7527bef3224c47e46ccb4a025c9d87a/genesis.yml
	cp genesis.yml ~/.tendermint/config/genesis.json
	rm genesis.yml
	wget https://raw.githubusercontent.com/bigchaindb/BEPs/master/23/config.toml
	#wget https://gist.githubusercontent.com/eckelj/2bfd09b869dd8fc04ce6310f0d458186/raw/80ae7c7c0c2ef4dcdb9467a70e94a08f35a0b1a5/config.toml
	cp config.toml ~/.tendermint/config/config.toml
	rm config.toml

clean-states:
	source venv/bin/activate
	planetmint drop
	tendermint unsafe-reset-all

check-deps:
ifndef IS_DOCKER_COMPOSE_INSTALLED
	@$(ECHO) "Error: docker-compose is not installed"
	@$(ECHO)
	@$(ECHO) "You need docker-compose to run this command. Check out the official docs on how to install it in your system:"
	@$(ECHO) "- https://docs.docker.com/compose/install/"
	@$(ECHO)
	@$(DC) # docker-compose is not installed, so we call it to generate an error and exit
endif

