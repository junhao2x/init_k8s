#!/bin/bash

display_usage() {
    echo -e "\nUsage: $0 --sock=<cri socket path> --role=master|worker\n"
    echo -e "Example: ./crio.sh --sock=/var/run/crio/crio.sock --role=master\n"
}

if [ $# -ne 2 ]; then
    display_usage
    exit 1
else
    while [ "$1" != "" ]; do
        PARAM=$(echo $1 | awk -F= '{print $1}')
        VALUE=$(echo $1 | awk -F= '{print $2}')
        case $PARAM in
        -h | --help)
            display_usage
            exit
            ;;
        -v | --sock)
            sock=$VALUE
            ;;
        -r | --role)
            role=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            display_usage
            exit 1
            ;;
        esac
        shift
    done
fi
# Ensure you load modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload sysctl
sudo sysctl --system

# Add Cri-o repo
OS="xUbuntu_20.04"
VERSION=1.22
sudo echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" >/etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
sudo echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" >/etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

sudo mkdir -p /usr/share/keyrings
sudo curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
sudo curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

apt-get update
apt-get install cri-o cri-o-runc

# Install CRI-O
sudo apt update
sudo apt install cri-o cri-o-runc -y

# Start and enable Service
sudo systemctl daemon-reload
sudo systemctl restart crio
sudo systemctl enable crio
# sudo systemctl status crio
if [[ "${role}" != "master" ]]; then
    echo -e "==============================================================="
    echo -e "Successfully Installed k8s ${role} node with cri-o as container runtime"
    echo -e "==============================================================="
    exit 1
else
    lsmod | grep br_netfilter
    sudo systemctl enable kubelet
    sudo kubeadm config images pull --cri-socket ${sock}
fi
