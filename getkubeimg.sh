#!/bin/bash
#Original Setting:
#images=(kube-proxy-amd64:v1.9.0 kube-scheduler-amd64:v1.9.0 kube-controller-manager-amd64:v1.9.0 kube-apiserver-amd64:v1.9.0 etcd-amd64:3.1.10 pause-amd64:3.0 kubernetes-dashboard-amd64:v1.8.3 k8s-dns-sidecar-amd64:1.14.7 k8s-dns-kube-dns-amd64:1.14.7 k8s-dns-dnsmasq-nanny-amd64:1.14.7)
#My setting
images=(kube-proxy-amd64:v1.10.0 kube-scheduler-amd64:v1.10.0 kube-controller-manager-amd64:v1.10.0 kube-apiserver-amd64:v1.10.0 etcd-amd64:3.1.12 pause-amd64:3.1 kubernetes-dashboard-amd64:v1.8.3 k8s-dns-sidecar-amd64:1.14.8 k8s-dns-kube-dns-amd64:1.14.8 k8s-dns-dnsmasq-nanny-amd64:1.14.8 flannel:v0.10.0-amd64)

for image in ${images[@]} ; do
  docker pull xuliu/$image
  #docker tag xuliu/$image gcr.io/google_containers/$image
  docker tag xuliu/$image k8s.gcr.io/$image
  docker rmi xuliu/$image
done
