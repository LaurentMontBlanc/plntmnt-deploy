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
    echo $2
    ssh -i ~/.keys/rddl_aws_bigchaindb.pem ubuntu@$1 $2 $3 $4 $5 $6 $7
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
    copy_to "./config/Planetmint-0.9.9.tar.gz" "$ip" "~/Planetmint-0.9.9.tar.gz"
    cmds="
        virtualenv -p /usr/bin/python3.9 venv;
        source venv/bin/activate;
        sudo apt install -y python3-pip;
        pip install ./Planetmint-0.9.9.tar.gz;"
    remote_exec "$ip" "$cmds"
}

remove_planetmint(){
    ip=$1
    cmds="rm -rf venv;"
    remote_exec "$ip" "$cmds"
}

install_tarantool(){
    ip=$1

    cmds="
        set -x e; 
        sudo rm /etc/apt/sources.list.d/tarantool_2.list;
        echo \"export LANGUAGE=en_US.UTF-8;export LANG=en_US.UTF-8;export LC_ALL=en_US.UTF-8\" >> ~/.bash_profile;
        source ~/.bash_profile;
        sudo apt-get -y install gnupg2;
        sudo apt-get -y install curl;
        curl https://download.tarantool.org/tarantool/release/series-2/gpgkey | sudo apt-key add -;
        sudo apt-get -y install lsb-release;
        release=`lsb_release -c -s`;
        echo ${release}
        sudo apt-get -y install apt-transport-https;
        sudo rm -f /etc/apt/sources.list.d/*tarantool*.list;
        echo \"deb https://download.tarantool.org/tarantool/release/series-2/ubuntu/ focal main\" | sudo tee /etc/apt/sources.list.d/tarantool_2.list;
        echo \"deb-src https://download.tarantool.org/tarantool/release/series-2/ubuntu/ focal main\" | sudo tee -a /etc/apt/sources.list.d/tarantool_2.list;
        sudo apt-get -y update;
        sudo apt-get -y install tarantool;
        "
#    cmds="sudo curl -L https://tarantool.io/KJPkHaG/release/2/installer.sh | bash;
#        sudo apt-get install -y tarantool;"
    remote_exec "$ip" "$cmds"
}

configure_tarantool(){
    ip=$1
    copy_to "./config/basic.lua" "$ip" "~/basic.lua"
    cmds="sudo cp -f basic.lua /etc/tarantool/instances.available/planetmint.lua;
    sudo systemctl stop tarantool@example.service;
    sudo rm -f /etc/tarantool/instances.enabled/example.lua;
    sudo ln -s -f /etc/tarantool/instances.available/planetmint.lua /etc/tarantool/instances.enabled/planetmint.lua;
    sudo systemctl restart tarantool.service;
    sudo systemctl enable tarantool@planetmint.service;
    sudo systemctl start tarantool@planetmint.service"
    remote_exec "$ip" "$cmds"
}

stop_tarantool(){
    ip=$1
    cmds="sudo systemctl restart tarantool.service;
    sudo systemctl stop tarantool@planetmint.service"
    remote_exec "$ip" "$cmds"
}

start_tarantool(){
    ip=$1
    cmds= "sudo systemctl start tarantool@planetmint.service"
    remote_exec "$ip" "$cmds"
}

status_tarantool(){
    ip=$1
    cmds= "sudo systemctl status tarantool@planetmint.service"
    remote_exec "$ip" "$cmds"
}

install_stack(){
    ip=$1
    install_deps "$ip"
    install_tm "$ip"
    #install_db "$ip"
    install_tarantool "$ip"
    install_python "$ip"
    install_nginx "$ip"
    install_planetmint "$ip"
    init_services "$ip"
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
    cmds='tendermint init;'
    remote_exec "$ip" "$cmds"
}
get_tm_identities(){
    ip=$1
    cmds=' cat ~/.tendermint/config/priv_validator_key.json; tendermint show_node_id'
    remote_exec "$ip" "$cmds"
}

config_tm(){
    ip=$1
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
    #copy_to "./config/planetmint-mongodb" $1 "test-network-planetmint"
    copy_to "./config/planetmint-tarantool" $1 "test-network-planetmint"
    cmds='cp test-network-planetmint ~/.planetmint;
    rm test-network-planetmint;'
    remote_exec "$ip" "$cmds"
}

fix_pl_deps(){
    ip=$1
    cmds='source venv/bin/activate;
    pip install protobuf==3.20.1;'
    remote_exec "$ip" "$cmds"
}



vote_approve(){
    ip=$1
    cmds='venv/bin/planetmint election approve --private-key ~/.tendermint/config/priv_validator_key.json'
    echo $cmds
    remote_exec "$ip" "$cmds" $2
}

vote_show(){
    ip=$1
    cmds='venv/bin/planetmint election show'
    echo $cmds
    remote_exec "$ip" "$cmds" $2
}

propose_election(){
    ip=$1
    cmds='venv/bin/planetmint election new upsert-validator --private-key ~/.tendermint/config/priv_validator_key.json'
    echo $cmds
    remote_exec "$ip" "$cmds" $2 $3 $4 $5
}

start_pl(){
    ip=$1
    cmds='sudo systemctl start planetmint.service;'
    remote_exec "$ip" "$cmds"
}
stop_pl(){
    ip=$1
    cmds='sudo systemctl stop planetmint.service;'
    remote_exec "$ip" "$cmds"
}

init_db(){
    ip=$1
    cmds='source venv/bin/activate && planetmint init;'
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
    cmds='source venv/bin/activate && planetmint -y drop; tendermint unsafe-reset-all'
    remote_exec "$ip" "$cmds"
}

verify_port(){
    ip=$1
    cmds='telnet localhost'
    remote_exec "$ip" "$cmds" "$2"
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

vi_pl(){
    ip=$1
    cmds='/bin/bash'
    remote_exec "$ip" "$cmds"
}

grant_access() {
    ip=$1
    cmds =    """
#    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDA+TWzvhZjdrzikcpBaD8zJSk3oDdxUOpymddCBlX78miQPv9SAb8koJFi3BAT5tsM/9gMeMhzJNs6JvjjIO/cUwKfpZ61cErLBjbRhq6z3+Y51vDOsIq6BH9d4DHSfLX9AQqePaFtxfcSBP9vD4lAMZZGMr14DrVeDKRfvPGHlyfaOSSd3d5N4oSBvPfnSOte1u5Go2uaOPqxaOiqw1EIBDPNCnpSe0rso+dlLNtoLDxpP5/hKe1XVQJMMAgFWfDRAjZ3ZebhFG4/2HUeH8sTfxM8d9vZ+W6qrkpYIVOyoYtjlmt796xDSC8G9tW14AvIybrVULRuSYcUq5stHuv++MqIxV1O3gXDXNSWwoEMvBnZlspiKvAvhCddFAO86rBa0ycb79b1MpAZQbjkcQ7D3PbQA7hzM9q1pGfW0cb8yn50FAipEsbVWK5Al4SFd/etKEDhWwbXtOtZ8yLedKBXut477MdccLG6Bg1iwRvttS/8QojWKopiaDwsF56Xe6c= pietro@Pietros-MacBook-Air.local" >> ~/.ssh/authorized_keys;
#    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEmwp6+4Hz99yDs/rurWI6j5x87zM3ckeA9ugINidsbrLUg6X8/7SL9/9T+3pzYzyYPw9XHlIL+mLkjbFA6DXtmJcIDlnAxrJMKC4BaLNnLsTgoCPbsnPuGl/m1iLXCFO6ypMXYnxxDyAfZpb6ei9P2tw4kYlCDRVSPRn452l3QWNCWvPkoSHvxioQDJwDGUXgU5GlXR3q86zKtaVxLd6mBAMMC7TEBVgRTbie4EAAcyVjFE+PoMMvDZa5zTecwu8j8I+bHsjUZfaHBeSqkZpI+F+mm8CjslbXC2S6mNQipc/0YbW5IceRfzjJBH1IT94wMKXG6Gm1ANFLWqpPsPGGSP+c3EYMV+1Efz+5ahv01f722nh1qztbDTZTrIgOCPnGK8ER0cjiB5zo63oW9+7H9pMX0hs4nGvcPdo9GZzVw74WXklpMe4YJSb2Dh7GCXekFbVsb1T3x0eAO6mg7WEalxaGL4vqO0Sy77W+41bDXvicEJ4stIdKZNz6egv8/XU= vasilis@vasilis-ThinkPad-T470-W10DG" >> ~/.ssh/authorized_keys;
#    echo "rsa-key-20220621-ik AAAAB3NzaC1yc2EAAAABJQAAAQEA8jsMw2je6iD+f2juR6vcah5qv3eE96pmbI7l7BV4GbinQYrgNucvJYraBL7in6F2ry1QiG1DZFYA1NVdkeUGZdDW8mEkegGlslxu9+Ug1Ggft+V8GJDKrPJiW2t42LahfObNrGh7VVK98LSqGWMnbYFYgbB5GXIOmv/XTB4k3NUyqyvsjamBmFAGeAw9KDsYnQvjmBLbKYHqzgeUKn4d/H5Q4Y+osf1we6DUVv1zaV9Iiv4mfLl0c+RZhSrCeb2Ny+271PrwLzEcWsv3MieiQDvYdn8VmehmE4fURBI7W7vROaa3EZstRRskN7eXWistBFlz6ntPRAaavW4ndX9z4Q== ioannis" >> ~/.ssh/authorized_keys;
#    echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEA7E+NDfoQ589dTgYwVRXN9xQn24I46X9/6Mo8RAQr8Btfrb7SYhjIKMI29yZdgEj3wiQla3rPu9ky084+ToDaRbHE4rNYF9jOK2CrEIQ8x/lfivdfIRWxPJHo/5FzFqX/mJM12AGjUpXyLCuilW8yKJU55mNK34U97r/TKpXFY1YwNGw1pe9InEhEXs9ithlkuQSdoeL+aAQLF+9O5NcZqXoZXyVx23xKLkQ2BrnAqy/TcpfQJRUUjCSJcCZTEX95lj8f+HqFtq3InRiE9RMrdwSlNGQyDZCF5RswbVwPEkeFw5f9q7OcWirYPi1523Mx45mcaMWrMKdBvoji/BUr3Q== andrea@dyne.org" >> ~/.ssh/authorized_keys;
#    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIgiin0QkmtwZXR1494cNEyYo8w7HBrUU6h2t27eUIV7 jrml@reflex" >> ~/.ssh/authorized_keys;
#    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHagTXqVxAxuLGOyjsze4Ct7h4iWmcYcCmuoktwESTsh alby@pc-asus" >> ~/.ssh/authorized_keys;
#    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpAzk/Y9Er5I9ZTzXXbggP6Ti/l7pnHfWl24/Wifv1A juergen@JE-ThinkPad-T480s" >> ~/.ssh/authorized_keys;
    """
    remote_exec "$ip"
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


#IPS=('3.73.50.172' '3.73.66.61' '3.69.169.21' '3.71.105.61') # EBSI Layer 0
config_env="./config/ebsi-layer0"

config='ebsi-layer0'

PS3="Select the operation: "
network=$1

case $network in
layer0)
    #IPS=('3.73.50.172' '3.73.66.61' '3.69.169.21' '3.71.105.61') # EBSI Layer 0 - initial nodes
    #IPS=('13.36.36.183' '15.188.11.249' '54.155.135.41' '54.229.224.120' '13.51.162.17' '16.171.30.78') # EBSI Layer 0 - added nodes
    #IPS=('3.73.50.172' '3.73.66.61' '3.69.169.21' '3.71.105.61' '13.36.36.183' '15.188.11.249' '54.155.135.41' '54.229.224.120' '13.51.162.17' '16.171.30.78') # EBSI Layer 0
    IPS=( '3.70.186.190' '3.73.66.61' '3.69.169.21' '3.71.105.61' '13.36.36.183' '15.188.11.249' '54.155.135.41' '54.229.224.120' '13.51.162.17' '16.171.30.78') # EBSI Layer 0
    #IPS=( '3.73.66.61' '3.69.169.21' '3.71.105.61' '13.36.36.183' '15.188.11.249' '54.155.135.41' '54.229.224.120' '13.51.162.17' '16.171.30.78') # EBSI Layer 0
    #IPS=(  '13.36.36.183' '15.188.11.249' '54.155.135.41' '54.229.224.120' '13.51.162.17' '16.171.30.78') # EBSI Layer 0
    #IPS=('16.171.30.78')
    #IPS=('3.69.169.21' )
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

devtest)
    #IPS=('3.72.48.166')  # test executor

    IPS=('3.70.186.190')
    ;;
*) 
    echo "Invalid option $REPLY"
    exit 1
    ;;
esac

case $2 in
install_deps)
    ;;
install_tm)
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
install_tarantool)
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
fix_pl_deps)
    ;;
vote_approve)
    ;;
vote_show)
    ;;
propose_election)
    ;;
get_tm_identities)
    ;;
grant_access)
    ;;
configure_tarantool)
    ;;
verify_port)
    ;;
vi_pl)
    ;;
start_pl)
    ;;
stop_pl)
    ;;
init_db)
    ;;
start_tarantool)
    ;;
stop_tarantool)
    ;;
status_tarantool)
    ;;
*)
    echo "Unknown option: $2"
    exit 1
    ;;
esac


for ip in "${IPS[@]}"
do
    echo "Executing on this IP " "$ip"
    $2 $ip $3 $4 $5
    if [[ "$2" == "propose_election" ]]
    then
        break
    fi
    echo "$ip"
done


