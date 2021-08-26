#!/bin/bash


JENKINS_HOME_LOCAL_USER=~/.jenkins
[ ! -d ${JENKINS_HOME_LOCAL_USER} ] && mkdir -p ${JENKINS_HOME_LOCAL_USER}
  
  cd ${JENKINS_HOME_LOCAL_USER}
  
  JENKINS_GIT_DIR=jenkins-kubernetes-pod
  [ -d ${JENKINS_GIT_DIR} ] && rm -rf ${JENKINS_GIT_DIR}
  git clone https://github.com/karlring-devops/jenkins-kubernetes-pod.git
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
