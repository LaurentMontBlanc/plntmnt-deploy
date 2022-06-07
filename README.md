# plntmnt-deploy
A deployment of Planetmint is usually done the following way:

install_deps
install_db
install_tm
install_nginx
install_python
install_planetmint
init_services "$ip"

this cann all be done via a single command execution:

install_stack

Thereafter, tendermint needs to be initialized once

init_tm
get_tm_identities


The config files of planetmint and tenermint might be updated (locally, edit config files) and deployed:

config_pl 
config_tm 

Services be installed and started
install_services
start_services




