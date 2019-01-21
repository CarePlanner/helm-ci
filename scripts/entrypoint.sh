#!/bin/bash
set -e

function error_exit
{
  echo "ERROR: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

#Suppress gpg setup messages with this throwaway command
gpg --list-keys >/dev/null 2>&1

if [ -z $SKIP_CERT_IMPORT ] ; then

  [ -d /root/.kube ] || mkdir /root/.kube
  [ -d /root/.helm ] || mkdir /root/.helm
  [ -z $ENCRYPTED_CERTS_DIR ] && ENCRYPTED_CERTS_DIR="/encrypted_certs.d"
  [ -d $ENCRYPTED_CERTS_DIR ] || error_exit "Could not find $ENCRYPTED_CERTS_DIR"

  [ -e "${ENCRYPTED_CERTS_DIR}/kms.key" ] || error_exit "Could not find ${ENCRYPTED_CERTS_DIR}/kms.key"
  KEY=$(aws kms decrypt --ciphertext-blob fileb://${ENCRYPTED_CERTS_DIR}/kms.key --output text --query Plaintext | base64 -d)

  # Kubectl setup, prefer EKS-IAM but fallback to K8S certs
  if aws eks describe-cluster --name $K8S_CLUSTER_NAME >/dev/null 2>&1 ; then
    aws eks update-kubeconfig --name $K8S_CLUSTER_NAME 1>/dev/null
  elif [ -e ${ENCRYPTED_CERTS_DIR}/k8s.key.gpg ] ; then
    echo $KEY | gpg --batch --passphrase-fd 0 -q -d ${ENCRYPTED_CERTS_DIR}/k8s.key.gpg >/root/.kube/key.pem || error_exit "Failed to set Kubernetes private key"
    echo $KEY | gpg --batch --passphrase-fd 0 -q -d ${ENCRYPTED_CERTS_DIR}/k8s.cert.gpg >/root/.kube/cert.pem || error_exit "Failed to set Kubernetes certificate"
    echo $KEY | gpg --batch --passphrase-fd 0 -q -d ${ENCRYPTED_CERTS_DIR}/k8s.ca.gpg >/root/.kube/ca.pem || error_exit "Failed to set Kubernetes CA certificate"

    kubectl config set-credentials circleci --client-key=$HOME/.kube/key.pem --client-certificate=$HOME/.kube/cert.pem 1>/dev/null
    kubectl config set-cluster $K8S_CLUSTER_NAME --certificate-authority=$HOME/.kube/ca.pem --server=https://$K8S_CLUSTER_API 1>/dev/null
    kubectl config set-context $K8S_CLUSTER_NAME --user $K8S_USER --cluster=$K8S_CLUSTER_NAME --namespace=$K8S_NAMESPACE 1>/dev/null
    kubectl config use-context $K8S_CLUSTER_NAME 1>/dev/null
  fi

  # Helm setup
  if [ -e ${ENCRYPTED_CERTS_DIR}/helm.key.gpg ] ; then
    [ -d /root/.helm ] || mkdir /root/.helm
    echo $KEY | gpg --batch --passphrase-fd 0 -q -d ${ENCRYPTED_CERTS_DIR}/helm.key.gpg >/root/.helm/key.pem || error_exit "Failed to set Helm private key"
    echo $KEY | gpg --batch --passphrase-fd 0 -q -d ${ENCRYPTED_CERTS_DIR}/helm.cert.gpg >/root/.helm/cert.pem || error_exit "Failed to set Helm certificate"
    echo $KEY | gpg --batch --passphrase-fd 0 -q -d ${ENCRYPTED_CERTS_DIR}/helm.ca.gpg >/root/.helm/ca.pem || error_exit "Failed to set Helm CA certificate"

    helm init --debug --client-only --kube-context $(kubectl config current-context) >/dev/null 2>&1 || true
    if [ "$HELM_REPO" != "" ] && [ "$HELM_REPO_URL" != "" ]; then
      helm repo add ${HELM_REPO} ${HELM_REPO_URL}
    fi
  fi

fi

exec "$@"
