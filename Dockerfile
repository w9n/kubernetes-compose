From alpine:edge AS build-base

RUN apk add -U --no-cache \
  bash \
  coreutils \
  curl \
  findutils \
  git \
  go \
  grep \
  libc-dev \
  linux-headers \
  make \
  rsync \
  && true

COPY --from=golang:alpine /usr/local/go /usr/local/go

ENV GOPATH=/go PATH=$PATH:/go/bin:/usr/local/go/bin

FROM build-base AS kubernetes

### Kubernetes (incl Kubelet)

ENV kubernetes_version v1.11.0
ENV cni_version        v0.7.1
ENV critools_version   v1.11.0

ENV KUBERNETES_URL https://github.com/kubernetes/kubernetes.git
#ENV KUBERNETES_BRANCH pull/NNN/head
ENV KUBERNETES_BRANCH ${kubernetes_version}
#ENV KUBERNETES_COMMIT
WORKDIR $GOPATH/src/github.com/kubernetes/kubernetes

RUN git clone $KUBERNETES_URL ./ --branch $KUBERNETES_BRANCH --depth 1

RUN git checkout $KUBERNETES_BRANCH

RUN make WHAT="cmd/kubelet cmd/kubectl cmd/kubeadm"

RUN mkdir -p /out/usr/bin

RUN cp $GOPATH/src/github.com/kubernetes/kubernetes/_output/bin/kubelet /out/usr/bin/kubelet
RUN cp $GOPATH/src/github.com/kubernetes/kubernetes/_output/bin/kubeadm /out/usr/bin/kubeadm
RUN cp $GOPATH/src/github.com/kubernetes/kubernetes/_output/bin/kubectl /out/usr/bin/kubectl

FROM build-base AS cni

### CNI plugins

ENV CNI_URL https://github.com/containernetworking/plugins
#ENV CNI_BRANCH pull/NNN/head
ENV CNI_COMMIT ${cni_version}
RUN mkdir -p $GOPATH/github.com/containernetworking/ && \
    cd $GOPATH/github.com/containernetworking/ && \
    git clone $CNI_URL plugins
WORKDIR $GOPATH/github.com/containernetworking/plugins
RUN set -e;  \
    if [ -n "$CNI_BRANCH" ] ; then \
        git fetch origin "CNI_BRANCH"; \
    fi; \
    git checkout -q $CNI_COMMIT
RUN ./build.sh

RUN mkdir -p /out/root
RUN tar -czf /out/root/cni.tgz -C $GOPATH/github.com/containernetworking/plugins/bin .

FROM build-base AS critools

### critools

ENV CRITOOLS_URL https://github.com/kubernetes-incubator/cri-tools
#ENV CRITOOLS_BRANCH pull/NNN/head
ENV CRITOOLS_COMMIT ${critools_version}
RUN mkdir -p $GOPATH/github.com/kubernetes-incubator/ && \
    cd $GOPATH/github.com/kubernetes-incubator/ && \
    git clone $CRITOOLS_URL cri-tools
WORKDIR $GOPATH/github.com/kubernetes-incubator/cri-tools
RUN set -e;  \
    if [ -n "$CRITOOLS_BRANCH" ] ; then \
        git fetch origin "CRITOOLS_BRANCH"; \
    fi; \
    git checkout -q $CRITOOLS_COMMIT
RUN make binaries

RUN mkdir -p /out/usr/bin
RUN cp $GOPATH/bin/crictl /out/usr/bin/crictl
RUN cp $GOPATH/bin/critest /out/usr/bin/critest


FROM alpine:edge AS build

## Construct final image

RUN mkdir -p /out/etc/apk && cp -r /etc/apk/* /out/etc/apk/
#coreutils needed for du -B for disk image checks made by kubelet
# example: $ du -s -B 1 /var/lib/kubelet/pods/...
#          du: unrecognized option: B
RUN apk add --no-cache --initdb -p /out \
    alpine-baselayout \
    busybox \
    ca-certificates \
    coreutils \
    curl \
    docker \
    ebtables \
    ethtool \
    findutils \
    iproute2 \
    iptables \
    musl \
    openssl \
    socat \
    util-linux \
    nfs-utils \
    && true



# Remove apk residuals. We have a read-only rootfs, so apk is of no use.
RUN rm -rf /out/etc/apk /out/lib/apk /out/var/cache

FROM scratch

COPY --from=kubernetes /out /
COPY --from=build /out /
COPY --from=cni /out /
COPY --from=critools /out /
COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY kubelet.sh /usr/bin/kubelet.sh
COPY calico.yml /cni/

ENTRYPOINT ["entrypoint.sh"]
ENV KUBECONFIG "/etc/kubernetes/admin.conf"
