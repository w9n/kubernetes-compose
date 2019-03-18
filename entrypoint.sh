#!/bin/sh

#just run...
rm /var/run/docker.pid
rm /var/run/docker/containerd/docker-containerd.pid
echo "nameserver 8.8.8.8" > /etc/resolv.conf


dockerd --data-root=/docker-state/$(cat /etc/hostname) 2&> /docker.log &

if [ ! -f /.init ]; then
    touch /.init
    {
    if [ -f /var/lib/kind/kubeadm ]; then
        eval $(cat /var/lib/kind/kubeadm)
    else
        eval $@
    fi
        kubectl apply -f /cni/cni.yml
    }&
fi

kubelet.sh
