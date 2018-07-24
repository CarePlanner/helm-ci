FROM alpine:3.7

ENV HELM_VERSION 2.8.2
ENV KUBECTL_VERSION 1.10.2
ENV SOPS_VERSION 3.0.5
ENV HELM_S3_PLUGIN_VERSION 0.6.1

# git branch lookup in circleci job requires: jq openssh-client git
# date parsing in qa_housekeeper requires: coreutils
RUN apk update && \
    apk add gnupg py2-pip bash git make curl jq openssh-client git coreutils && \
    pip install awscli

ADD https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl /usr/bin/kubectl
#ADD kubectl /usr/bin/kubectl
ADD https://storage.googleapis.com/kubernetes-helm/helm-v$HELM_VERSION-linux-amd64.tar.gz /tmp/helm.tgz
#ADD helm-binary /usr/bin/helm
ADD https://github.com/mozilla/sops/releases/download/$SOPS_VERSION/sops-$SOPS_VERSION.linux /usr/bin/sops

COPY scripts/* /usr/bin/

RUN tar -zxf /tmp/helm.tgz linux-amd64/helm --strip-components 1 -C /usr/bin && \
    rm -f /tmp/helm.tgz && \
    chmod +x /usr/bin/kubectl /usr/bin/helm /usr/bin/sops /usr/bin/entrypoint.sh && \
    mkdir -p /root/.helm/plugins && \
    helm plugin install https://github.com/hypnoglow/helm-s3.git --version $HELM_S3_PLUGIN_VERSION

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["kubectl", "--help"]
