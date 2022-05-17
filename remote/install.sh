#!/bin/bash
IPS=()
config_env=""

verify_port(){
    #ip=$1
    #cmd=$2
    telnet $1 $2
}

remote_exec(){
    #ip=$1
    #cmd=$2
    ssh -i ~/.keys/rddl_aws_bigchaindb.pem ubuntu@$1 $2
}

copy_to(){
    #file=$1
    #ip=$2
    #path=$3
    scp -i ~/.keys/rddl_aws_bigchaindb.pem $1 ubuntu@$2:$3
}

install_deps(){
    ip=$1
    cmds='sudo apt install -y make git'
    remote_exec "$ip" "$cmds"
}
install_db(){
    ip=$1
    cmds="sudo apt update; sudo apt install -y mongodb"
    remote_exec "$ip" "$cmds"
}
install_tm(){
    ip=$1
    cmds="wget https://github.com/tendermint/tendermint/releases/download/v0.34.15/tendermint_0.34.15_linux_amd64.tar.gz;
    tar zxf tendermint_0.34.15_linux_amd64.tar.gz;
    rm tendermint_0.34.15_linux_amd64.tar.gz *.md LICENSE;
    sudo mv tendermint /usr/local/bin;
    /usr/local/bin/tendermint init"
    remote_exec "$ip" "$cmds"
}

install_python(){
    ip=$1
    cmds="sudo add-apt-repository ppa:deadsnakes/ppa;
        sudo apt-get update;
        sudo apt-get install -y python3.9 python3.9-dev;
        sudo apt-get update;
        sudo apt-get install -y python3-virtualenv;"
    remote_exec "$ip" "$cmds"

}

install_planetmint(){
    ip=$1
    cmds="
        virtualenv -p /usr/bin/python3.9 venv;
        source venv/bin/activate;

        pip install planetmint;"
    remote_exec "$ip" "$cmds"
}

remove_planetmint(){
    ip=$1
    cmds="rm -rf venv;"
    remote_exec "$ip" "$cmds"
}


install_stack(){
    ip=$1
    install_deps "$ip"
    install_tm "$ip"
    install_db "$ip"
    install_python "$ip"
    install_planetmint "$ip"
}

install_services(){
    ip=$1
    
    copy_to "./config/planetmint.service" "$ip" "~/planetmint.service"
    copy_to "./config/tendermint.service" "$ip" "~/tendermint.service"
    
    cmds='sudo cp planetmint.service /etc/systemd/system/;
    sudo cp tendermint.service /etc/systemd/system/;
    sudo rm planetmint.service;
    sudo rm tendermint.service'
    remote_exec "$ip" "$cmds"
}

install_nginx(){
    copy_to "./config/nginx.default" "$ip" "~/nginx.default"
    cmds='sudo apt install -y nginx;
    sudo cp ~/nginx.default /etc/nginx/sites-available/default;
    sudo /etc/init.d/nginx restart
    '
    remote_exec "$ip" "$cmds"
}

init_services(){
    ip=$1
    cmds='sudo systemctl daemon-reload;
        sudo systemctl enable planetmint.service;
        sudo systemctl enable tendermint.service;'
    remote_exec "$ip" "$cmds"
}

init_tm(){
    ip=$1
    ## be careful to not reinit tendermint because the identites of the nodes will change
    #cmds='tendermint init; cat ~/.tendermint/config/priv_validator_key.json; tendermint show_node_id'
    #cmds=' cat ~/.tendermint/config/priv_validator_key.json; tendermint show_node_id'
    cmds='tendermint show_node_id'
    remote_exec "$ip" "$cmds"
}

config_tm(){
    ip=$1
#    cmds='wget https://gist.githubusercontent.com/eckelj/c0da0e9b32594782e75b1e9161c832dc/raw/cdc0404fd1e09a0740927cec82f18b722757a53d/test-network-genesis.json;
#    cp test-network-genesis.json ~/.tendermint/config/genesis.json;
#    rm test-network-genesis.json;
#    wget https://gist.githubusercontent.com/eckelj/128c5ad6961cbec0a83c3476034039c8/raw/e7d45b9ba01ac1a2ada95c448c02fc0a7e1621e5/ebsi-testnet-config.yaml;
#    cp ebsi-testnet-config.yaml ~/.tendermint/config/config.toml;
#    rm ebsi-testnet-config.yaml'

    copy_to "$config_env/config.yaml" $1 "ebsi-testnet-config.yaml"
    cmds='cp ebsi-testnet-config.yaml ~/.tendermint/config/config.toml;
    rm ebsi-testnet-config.yaml'
    remote_exec "$ip" "$cmds"


    copy_to "$config_env/genesis.json" $1 "test-network-genesis.json"
    #cmds='wget https://gist.githubusercontent.com/eckelj/c0da0e9b32594782e75b1e9161c832dc/raw/1273152bc3803bd3605d486d514697c92106a32c/test-network-genesis.json;
    cmds='cp test-network-genesis.json ~/.tendermint/config/genesis.json;
    rm test-network-genesis.json'
    remote_exec "$ip" "$cmds"
}

config_pl(){
    ip=$1
    copy_to "./config/planetmint" $1 "test-network-planetmint"
    cmds='cp test-network-planetmint ~/.planetmint;
    rm test-network-planetmint;'
    remote_exec "$ip" "$cmds"
}

start_services(){
    ip=$1
    cmds='sudo systemctl start tendermint.service; sudo systemctl start planetmint.service;'
    remote_exec "$ip" "$cmds"
}
stop_services(){
    ip=$1
    cmds='sudo systemctl stop planetmint.service; sudo systemctl stop tendermint.service'
    remote_exec "$ip" "$cmds"
}
status_services(){
    ip=$1
    cmds='sudo systemctl status tendermint.service; sudo systemctl status planetmint.service;'
    remote_exec "$ip" "$cmds"
}

reset_data(){
    ip=$1
    cmds='source venv/bin/activate && planetmint drop; tendermint unsafe-reset-all'
    remote_exec "$ip" "$cmds"
}

basic_check(){
    ip=$1
    curl http://$ip:9984
}

has_tx(){
    ip=$1
    tx_id=$2
    curl http://$1:9984/api/v1/transactions/$tx_id
}

list_ips(){
    echo "$1"
}



#OSITIONAL_ARGS=()
#while [[ $# -gt 0 ]]; do
#  case $1 in
#    --install-deps)
#      EXTENSION="$2"
#      shift # past argument
#      shift # past value
#      ;;
#    -s|--searchpath)
#      SEARCHPATH="$2"
#      shift # past argument
#      shift # past value
#      ;;
#    --default)
#      DEFAULT=YES
#      shifinstall_stackt # past argument
#      ;;
#    -*|--*)
#      echo "Unknown option $1"
#      exit 1
#      ;;
#    *)
#      POSITIONAL_ARGS+=("$1") # save positional arg
#      shift # past argument
#      ;;
#  esac
#done


IPS=('3.73.50.172' '3.73.66.61' '3.69.169.21' '3.71.105.61') # EBSI Layer 0
config_env="./config/ebsi-layer0"

config='ebsi-layer0'

PS3="Select the operation: "
network=$1

case $network in
layer0)
    IPS=('3.73.50.172' '3.73.66.61' '3.69.169.21' '3.71.105.61') # EBSI Layer 0
    config_env="./config/ebsi-layer0"
    ;;
layer1)
    IPS=('3.66.221.17' '3.123.40.222' '3.72.94.104' '3.68.108.18')  # EBSI Layer 1
    config_env="./config/ebsi-layer1"
    ;;
test.ipdb.io)
    IPS=('3.70.11.61') # test.ipdb.io
    config_env="./config/test.ipdb.io"
    ;;
*) 
    echo "Invalid option $REPLY"
    exit 1
    ;;
esac

case $2 in
install_deps)
    ;;
install_db_tm)
    ;;
install_db)
    ;;
install_nginx)
    ;;
install_planetmint)
    ;;
install_stack)
    ;;
install_python)
    ;;
remove_planetmint)
    ;;
init_tm)
    ;;
config_pl)
    ;;
config_tm)
    ;;
stop_services)
    ;;
install_services)
    ;;
init_services)
    ;;
start_services)
    ;;
reset_data)
    ;;
status_services)
    ;;
verify_port)
    ;;
has_tx)
    ;;
basic_check)
    ;;
list_ips)
    ;;
*)
    echo "Unknown option: $2"
    exit 1
    ;;
esac


for ip in "${IPS[@]}"
do
    echo "Executing on this IP " "$ip"
    #install_deps "$ip"
    #install_db_tm "$ip"
    #install_db "$ip"
    #install_nginx "$ip"
    #install_planetmint "$ip"
    #install_stack "$ip"

    #init_tm "$ip"
    #config_pl "$ip"
    #config_tm "$ip"
    #init_tm "$ip"

    #stop_services "$ip"
    #install_services "$ip"
    #init_services "$ip"
    #start_services "$ip"
    
    #init_tm "$ip"
    
    #config_tm "$ip"
    #config_pl "$ip"
    #stop_services "$ip"
    #reset_data "$ip"
    #start_services "$ip"
    $2 $ip $3
    #status_services "$ip"
    #basic_check "$ip"
    #has_tx "$ip" $1
    #stop_services "$ip"
    #verify_port "$ip" $1
    echo "$ip"
done


