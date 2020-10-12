FROM alpine:3.11

ENV HELM_VERSION 3.3.4
ENV KUBECTL_VERSION 1.16.15
ENV SOPS_VERSION 3.0.5

# git branch lookup in circleci job requires: jq openssh-client git
# date parsing in qa_housekeeper requires: coreutils
RUN apk add --no-cache gnupg python2 py2-pip bash git make curl jq openssh-client git coreutils && \
    pip install awscli && \
    apk --purge -v del py2-pip && \
    rm -rf /var/cache/apk/*

ADD https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl /usr/bin/kubectl
ADD https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz /tmp/helm.tgz
ADD https://github.com/mozilla/sops/releases/download/$SOPS_VERSION/sops-$SOPS_VERSION.linux /usr/bin/sops

COPY scripts/* /usr/bin/

RUN tar -zxf /tmp/helm.tgz linux-amd64/helm --strip-components 1 -C /usr/bin && \
    rm -f /tmp/helm.tgz && \
    mv /usr/bin/helm /usr/bin/helm3 && \
    ln -s /usr/bin/helm3-bc.sh /usr/bin/helm && \
    chmod +x /usr/bin/kubectl /usr/bin/helm3 /usr/bin/sops /usr/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["kubectl", "--help"]
