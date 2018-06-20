#!/bin/sh

#just run...
rm /var/run/docker.pid
rm /var/run/docker/containerd/docker-containerd.pid

dockerd --data-root=/docker-state/$(cat /etc/hostname) 2&> /docker.log &

if [ ! -f /.init ]; then
    touch /.init
    {
    eval $@ && \
        kubectl apply -f /cni/calico.yml
    }&
fi

kubelet.sh
