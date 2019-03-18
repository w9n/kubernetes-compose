# kubernetes-compose

most basic kubernetes components compiled from source.

#### Multi node kubernetes cluster on docker container

+ Kubernetes 1.13
+ cni plugins 0.7.5
+ flannel v0.11.0
+ critools v1.13.0
+ <100 lines of bash

## Usage

docker-compose up --scale node=X
