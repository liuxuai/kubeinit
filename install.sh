#!/bin/bash

#Your Kubernetes master has initialized successfully!
#To start using your cluster, you need to run the following as a regular user:
#You should now deploy a pod network to the cluster.
#Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
#  https://kubernetes.io/docs/concepts/cluster-administration/addons/
#You can now join any number of machines by running the following on each node
#as root:
#  kubeadm join 192.168.1.6:6443 --token klxqkq.c0i79fei3pi5b7mj --discovery-token-ca-cert-hash sha256:5ad205217223d919f9519d08860164d30cbd8343e4e3f768b679410fcecc2d6b
#  kubeadm join $MASTERIP:$MASTERPORT --token $MASTERTOKEN  --discovery-token-ca-cert-hash sha256:$MASTERHASH

# KUBE_REPO_PREFIX=registry.cn-hangzhou.aliyuncs.com/google-containers
# KUBE_HYPERKUBE_IMAGE=registry.cn-hangzhou.aliyuncs.com/google-containers/hyperkube-amd64:v1.7.0
# KUBE_DISCOVERY_IMAGE=registry.cn-hangzhou.aliyuncs.com/google-containers/kube-discovery-amd64:1.0
# KUBE_ETCD_IMAGE=registry.cn-hangzhou.aliyuncs.com/google-containers/etcd-amd64:3.0.17

# KUBE_REPO_PREFIX=$KUBE_REPO_PREFIX KUBE_HYPERKUBE_IMAGE=$KUBE_HYPERKUBE_IMAGE KUBE_DISCOVERY_IMAGE=$KUBE_DISCOVERY_IMAGE kubeadm init --ignore-preflight-errors=all --pod-network-cidr="10.244.0.0/16"

#export KUBE_REPO_PREFIX=gcr.io/google_containers

set -x

USER=scott # 用户   #Modified by Scott
GROUP=scott # 组   #Modified by Scott
FLANELADDR=https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml
KUBECONF=/home/ubuntu/kubeadm.conf # 文件地址, 改成你需要的路径
REGMIRROR=192.168.1.7:5000 #YOUR_OWN_DOCKER_REGISTRY_MIRROR_URL # docker registry mirror 地址

# you can get the following values from `kubeadm init` output
# these are needed when creating node
MASTERTOKEN=yvwlm8.bxi9ceic5cuxzfxm
MASTERIP=192.168.1.6
MASTERPORT=6443
MASTERHASH=4074aed549027b2b14fc0e0184ccd12f441546eef308914c5737da8b27a429d5

install_docker() {
  mkdir /etc/docker
  mkdir -p /data/docker
#  cat << EOF > /tmp/daemon.json
  cat << EOF > /etc/docker/daemon.json
{
  "registry-mirrors": ["$REGMIRROR"],
  "graph": "/data/docker"
}
EOF

  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl software-properties-common

  #For ustc
  #curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  #"deb [arch=amd64] https://mirrors.ustc.edu.cn/docker-ce/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"
  
  #For aliyun  
  curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
  add-apt-repository \
   "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update && sudo apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 17.09 | head -1 | awk '{print $3}')
}

add_user_to_docker_group() {
  groupadd docker
  gpasswd -a $USER docker # ubuntu is the user name
}

install_kube_commands() {
  #For ustc
  #cat kube_apt_key.gpg | apt-key add -
  #echo "deb [arch=amd64] https://mirrors.ustc.edu.cn/kubernetes/apt/kubernetes-$(lsb_release -cs) main" >> /etc/apt/sources.list
  
  #For aliyun
  curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
  echo "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main" >> /etc/apt/sources.list  
  
  #apt-cache policy kubeadm #查看版本号，按这种版本来安装
  #apt-get purge kubelet kubeadm kubectl #删除错误的版本
  #apt-get update && apt-get install -y kubelet kubeadm kubectl #安装最后版本
  apt-get update && apt-get install kubeadm=1.10.5-00 kubectl=1.10.5-00 kubelet=1.10.5-00
}

restart_kubelet() {
  #sed -i "s,ExecStart=$,Environment=\"KUBELET_EXTRA_ARGS=--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.1\"\nExecStart=,g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  sed -i "s,ExecStart=$,Environment=\"KUBELET_EXTRA_ARGS=--pod-infra-container-image=k8s.gcr.io/pause-amd64:3.1\"\nExecStart=,g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  
  systemctl daemon-reload
  systemctl restart kubelet
}

enable_kubectl() {
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

# for now, better to download from original registry
apply_flannel() {
  kubectl apply -f $FLANELADDR
}

case "$1" in
  "pre")
    install_docker  # Modified by Scott, already have Docker
    add_user_to_docker_group # Modified by Scott, user already in docker group
    install_kube_commands
    ;;
  "kubernetes-master")
    ufw disable
    swapoff -a #刚开机就运行，会成功，可能这个时候还没用到swap或者用的不多
    sysctl net.bridge.bridge-nf-call-iptables=1
    restart_kubelet
    #kubeadm init --config $KUBECONF
    #kubeadm init --kubernetes-version=v1.10.0 --pod-network-cidr=10.244.0.0/16 --node-name=master
    kubeadm reset
    kubeadm init --kubernetes-version=1.10.0 --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.1.6
    kubectl apply -f kube-flannel-legacy.yml 
    kubectl apply -f kube-flannel-rbac.yml 
    kubectl taint nodes --all node-role.kubernetes.io/master-  #需要master运行pod的话
    ;;
  "kubernetes-node")
    ufw disable
    swapoff -a #刚开机就运行，会成功，可能这个时候还没用到swap或者用的不多
    sysctl net.bridge.bridge-nf-call-iptables=1
    restart_kubelet
    swapoff -a #刚开机就运行，会成功，可能这个时候还没用到swap或者用的不多
    kubeadm join --token $MASTERTOKEN $MASTERIP:$MASTERPORT --discovery-token-ca-cert-hash sha256:$MASTERHASH
    ;;
  "post")
    if [[ $EUID -ne 0 ]]; then
      echo "do not run as root"
      exit
    fi
    enable_kubectl
    apply_flannel
    ;;
    "reset")
    kubeadm reset
    kubeadm init --kubernetes-version=1.10.0 --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.1.6
    ;;
  *)
    echo "huh ????"
    ;;
esac

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    #非Master执行kubectl
    #scp root@&lt;master ip&gt;:/etc/kubernetes/admin.conf .
    #kubectl --kubeconfig ./admin.conf get nodes

    #删除节点
    #kubectl drain ubuntu-002 --delete-local-data --force--ignore-daemonsets --kubeconfig ./admin.conf 
    #kubectl delete node ubuntu-002 --kubeconfig admin.conf 
    #kubeadm reset

    #wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml
    #wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-legacy.yml
    
    #kubectl delete -f kube-flannel-rbac.yml 
    #kubectl delete -f kube-flannel-legacy.yml 
    #kubectl apply -f kube-flannel-legacy.yml 
    #kubectl apply -f kube-flannel-rbac.yml 
    #kubectl describe po kube-dns-86f4d74b45-tv9pt  -n kube-system
    #kubectl get pod --all-namespaces -o wide

    

