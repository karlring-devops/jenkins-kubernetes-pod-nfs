#!/bin/bash

jk8snfs_setup(){
JENKINS_HOME_LOCAL_USER=~/.jenkins
[ ! -d ${JENKINS_HOME_LOCAL_USER} ] && mkdir -p ${JENKINS_HOME_LOCAL_USER}
  
  cd ${JENKINS_HOME_LOCAL_USER}
  
  #JENKINS_GIT_DIR=jenkins-kubernetes-pod
  JENKINS_GIT_DIR=jenkins-kubernetes-pod-nfs
  [ -d ${JENKINS_GIT_DIR} ] && rm -rf ${JENKINS_GIT_DIR}
  #git clone https://github.com/karlring-devops/jenkins-kubernetes-pod.git
  git clone https://github.com/karlring-devops/jenkins-kubernetes-pod-nfs.git
  cd ${JENKINS_GIT_DIR}
  
  kubectl create -f jenkins-namespace.yaml
  kubectl apply -f jenkins-role.yaml
  kubectl apply -f jenkins-role-bind.yaml
  kubectl create serviceaccount jenkins-admin-sa -n jenkins
  kubectl create clusterrolebinding jenkins-admin-sa --clusterrole=cluster-admin --serviceaccount=jenkins:jenkins-admin-sa -n jenkins

  kubectl create -f create-pv-jenkins.yaml
  kubectl create -f create-pv-claim-jenkins.yaml
  kubectl create -f jenkins-deployment.yaml
  kubectl create -f jenkins-service.yaml --validate=false
  kubectl create -f jenkins-service-jnlp.yaml
  kubectl scale -n jenkins deployment jenkins --replicas=1
}

jlogin(){
#/--- Get Jenkins Login Details ------/
        K8S_MASTER_IP=$(kubectl get nodes -o wide | grep master | awk '{ print $6 }' ;) 
    JENKINS_NODE_PORT=$(kubectl get services --namespace jenkins | grep 'NodePort' | awk '{print $5}' | sed -e 's|\/|:|g' | awk -F':' '{print $2}' ; )
     K8S_SERVICE_NAME=$(kubectl get pods -n jenkins | grep jenkins | head -1 | awk '{print $1}' ; )
  JENKINS_INIT_PASSWD=$(kubectl exec ${K8S_SERVICE_NAME} -n jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword)

    cat <<EOF
    /---------- JENKINS LOGIN DETAILS ----------/
    Jenkins Login URL     :    http://${K8S_MASTER_IP}:${JENKINS_NODE_PORT}
    Initial Admin Password: ${JENKINS_INIT_PASSWD}
EOF
}

setup_nfs_master(){
    #--- do this on the NFS Server before running -- jk8snfs_setup()
    sudo apt update
    sudo apt install nfs-common
    sudo apt-get update
    sudo apt install nfs-kernel-server

    sudo mkdir -p /home/public/var/jenkins/home
    sudo chown nobody:nogroup /home/public/var/jenkins/home
    sudo chmod 777 /home/public/var/jenkins/home

    cat <<EOF>>/etc/exports
    /home/public/var/jenkins/home *(rw,sync,no_subtree_check)
EOF

    sudo exportfs -ra
    sudo systemctl restart nfs-kernel-server.service
}

