#!/bin/sh
exec 1>&2

until [ -f "/etc/kubernetes/kubelet.conf" ] \
   || [ -f "/etc/kubernetes/bootstrap-kubelet.conf" ] ; do
    sleep 1
done

echo "bootstrap file has arrived" 2>&1

mkdir -p /etc/kubernetes/manifests

exec kubelet --kubeconfig=/etc/kubernetes/kubelet.conf \
	      --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
	      --pod-manifest-path=/etc/kubernetes/manifests \
	      --allow-privileged=true \
	      --cluster-dns=10.96.0.10 \
	      --cluster-domain=cluster.local \
	      --enforce-node-allocatable= \
	      --network-plugin=cni \
	      --cni-conf-dir=/etc/cni/net.d \
	      --cni-bin-dir=/opt/cni/bin \
          --fail-swap-on=false \
	      $KUBELET_ARGS $@
