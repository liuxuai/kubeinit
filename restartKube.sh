setenforce 0
swapoff -a
systemctl stop kubelet
systemctl stop docke
iptables -P FORWARD ACCEPT
iptables --flush
iptables -tnat --flush
systemctl start kubelet
systemctl start docker
echo "Wait few minutes until 'sudo kubectl get po --all-namespaces' all running"
