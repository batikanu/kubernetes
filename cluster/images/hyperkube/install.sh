#!/bin/bash
node_type=$1
master_IP=$2
node_IP=$3
pause_image=${4:-gcr.io/google_containers/pause:2.0}

if [ "$node_type" != "master" ] && [ "$node_type" != "minion" ]; then
  echo "Error: expected 'master' or 'minion' as argument"
  exit 1
fi

if [ -z $master_IP ]; then
  echo "Error: IP of the master node not specified"
  exit 1
fi

if [ -z $node_IP ]; then
  echo "Error: IP of the currently provisioned node is not specified"
  exit 1
fi

# copy cni
cp -R /opt/cni /hostfs/opt
cp /usr/bin/nsenter /hostfs/usr/bin

# copy cni configuration
mkdir -p /hostfs/etc/cni
cp -R /etc/cni/net.d /hostfs/etc/cni

# copy hyperkube binary
cp /hyperkube /hostfs/usr/bin/

if [ "$node_type" == "master" ]; then
  # clean up old configuration
  mkdir -p /hostfs/etc/kubernetes/manifests
  mkdir -p /hostfs/etc/kubernetes/addons

  # copy master components and addons
  cp /etc/kubernetes/manifests-multi/master-multi.json /hostfs/etc/kubernetes/manifests/
  cp /etc/kubernetes/manifests-multi/addon-manager.json /hostfs/etc/kubernetes/manifests/
  cp -R /etc/kubernetes/addons /hostfs/etc/kubernetes
fi

cat <<EOF >/hostfs/etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStart=/usr/bin/hyperkube kubelet \\
    --allow-privileged=true \\
    --hostname-override=${node_IP} \\
    --address=0.0.0.0 \\
    --api-servers=http://${master_IP}:8080 \\
    --config=/etc/kubernetes/manifests \\
    --cluster-dns=10.0.0.10 \\
    --cluster-domain=cluster.local \\
    --pod-infra-container-image=${pause_image} \\
    --network-plugin=cni \\
    --network-plugin-dir=/etc/cni/net.d \\
    --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
