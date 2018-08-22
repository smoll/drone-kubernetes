#!/bin/bash

print_secret() {
  name=$1
  secret=$2

  if [ -z ${secret} ]; then
    echo "INFO: No $name set"
  elif [ ${#secret} -ge 20 ]; then
    echo "INFO: Using $name: ${secret:0:5}*****${secret:(-3)}"
  else
    echo "INFO: Using $name: ${secret:0:2}*****${secret:(-1)}"
  fi
}

if [ -z ${PLUGIN_NAMESPACE} ]; then
  PLUGIN_NAMESPACE="default"
fi

if [ -z ${PLUGIN_KUBERNETES_USER} ]; then
  PLUGIN_KUBERNETES_USER="default"
fi

if [ ! -z ${PLUGIN_KUBERNETES_SERVER} ]; then
  KUBERNETES_SERVER=$PLUGIN_KUBERNETES_SERVER
fi

if [ ! -z ${PLUGIN_KUBERNETES_TOKEN} ]; then
  KUBERNETES_TOKEN=$PLUGIN_KUBERNETES_TOKEN
fi

if [ ! -z ${PLUGIN_KUBERNETES_CERT} ]; then
  KUBERNETES_CERT=${PLUGIN_KUBERNETES_CERT}
fi

if [ ! -z ${PLUGIN_KUBERNETES_ENV} ]; then
  env_prefix=$(echo $PLUGIN_KUBERNETES_ENV | tr [a-z] [A-Z])
  echo "INFO: Overriding vars using env prefix: ${env_prefix}"
  server_varname=${env_prefix}_KUBERNETES_SERVER
  token_varname=${env_prefix}_KUBERNETES_TOKEN
  cert_varname=${env_prefix}_KUBERNETES_CERT

  if [ ! -z ${!server_varname} ]; then
    KUBERNETES_SERVER=${!server_varname}
  fi

  if [ ! -z ${!token_varname} ]; then
    KUBERNETES_TOKEN=${!token_varname}
  fi

  if [ ! -z ${!cert_varname} ]; then
    KUBERNETES_CERT=${!cert_varname}
  fi
fi

if [ -z ${PLUGIN_TAG} ]; then
  echo "INFO: no docker tag set"
else
  echo "INFO: Using docker tag: ${PLUGIN_TAG}"
fi

print_secret token $KUBERNETES_TOKEN
print_secret cert $KUBERNETES_CERT

kubectl config set-credentials default --token=${KUBERNETES_TOKEN}
if [ ! -z ${KUBERNETES_CERT} ]; then
  echo ${KUBERNETES_CERT} | base64 -d > ca.crt
  kubectl config set-cluster default --server=${KUBERNETES_SERVER} --certificate-authority=ca.crt
else
  echo "WARNING: Using insecure connection to cluster"
  kubectl config set-cluster default --server=${KUBERNETES_SERVER} --insecure-skip-tls-verify=true
fi

kubectl config set-context default --cluster=default --user=${PLUGIN_KUBERNETES_USER}
kubectl config use-context default

# kubectl version
IFS=',' read -r -a DEPLOYMENTS <<< "${PLUGIN_DEPLOYMENT}"
IFS=',' read -r -a CONTAINERS <<< "${PLUGIN_CONTAINER}"
for DEPLOY in ${DEPLOYMENTS[@]}; do
  echo Deploying to $KUBERNETES_SERVER
  for CONTAINER in ${CONTAINERS[@]}; do
    if [[ ${PLUGIN_FORCE} == "true" ]]; then
      kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
        ${CONTAINER}=${PLUGIN_REPO}:${PLUGIN_TAG}FORCE
    fi
    kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
      ${CONTAINER}=${PLUGIN_REPO}:${PLUGIN_TAG} --record
  done
done
