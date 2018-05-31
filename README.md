# Helm-CI

----

A docker image for running helm/kubectl with certificates encrypted using AWS KMS

We deploy to kubernetes from our CircleCI pipeline and needed a way to allow helm (and kubectl) to run in that pipeline but keeping our k8s and helm certificates secure.

We encrypt the certificates using envelope encryption - the certificates are encrypted with GPG which uses a key stored in AWS KMS. This means we can safely store the certificates in the repo alongside our code.

This image will get the GPG key from AWS KMS at start up and then decrypt-and-import the certificates ready for use by helm/kubectl, the docker image just needs to be passed a set of IAM keys.

----

### Prerequisites:

**Create a KMS CMK and get it's ID.**

(We do this in terraform, you might do it in the console or cli)

**Generate a key and store it in KMS:**
```
KEY=$(aws kms generate-random --number-of-bytes 128 | jq .Plaintext | tr -d \")
aws kms encrypt --key-id $KMS_KEY_ID --plaintext fileb://<(echo $KEY) --query CiphertextBlob --output text | base64 -d >kms.key
```

**Encrypt your certificates:**
```
for i in k8s.key.pem k8s.cert.pem k8s.ca.pem helm.key.pem helm.cert.pem helm.ca.pem ; do
  cat $i | gpg --batch --passphrase-file <(echo $KEY) --symmetric --cipher-algo AES256 >${i%.pem}.gpg
```

**Store those encrypted certificates and the encrypted key in a directory somewhere**
We keep them in our repo:
```
cp *.gpg kms.key /my/repo/certs/
cd /my/repo
git add certs
git commit -m "Encrypted certs in the repo"
```

### Requirements:

The docker image needs to be passed several environment variables:

- `AWS_DEFAULT_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `K8S_CLUSTER_NAME`
- `K8S_NAMESPACE`
- `K8S_USER`

Optional (required if you use the excellent [helm s3 plugin](https://github.com/hypnoglow/helm-s3))

- `HELM_REPO`
- `HELM_REPO_URL`

The encryted certs directory needs to be mounted into the docker container as volume, e.g:

`-v /my/repo/certs:/encrypts_certs.d`

If you want to pass in helm values as yaml files, this needs to be mounted too, e.g:

`-v /my/repo/helm/values:/helm.d`

### Examples:

Here's an example of using the image to list all helm deployments:

```
docker build -t myregistry/helm-ci

docker run -it \
-e AWS_DEFAULT_REGION=eu-west-1 \
-e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
-e K8S_CLUSTER_NAME=k8s.somewhere.com \
-e K8S_NAMESPACE=dev \
-e K8S_USER=circleci \
-e HELM_REPO=my-helm-repo \
-e HELM_REPO_URL="s3://somebucket/charts" \
-v /home/circleci/project/build/helm/dev/certs:/encrypted_certs.d \
-v /home/circleci/project/build/helm/dev/values:/helm.d \
myregistry/helm-ci \
helm list --tls
```

Here's an example of using the image to upgrade a helm deployment:

```
docker build -t myregistry/helm-ci

docker run -it \
-e AWS_DEFAULT_REGION=eu-west-1 \
-e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
-e K8S_CLUSTER_NAME=k8s.somewhere.com \
-e K8S_NAMESPACE=dev \
-e K8S_USER=circleci \
-e HELM_REPO=my-helm-repo \
-e HELM_REPO_URL="s3://somebucket/charts" \
-v /home/circleci/project/build/helm/dev/certs:/encrypted_certs.d \
-v /home/circleci/project/build/helm/dev/values:/helm.d \
myregistry/helm-ci \
helm upgrade dev-myhelmapp my-helm-repo/myhelmchart -f /helm.d/myvalues.yaml --tls --debug
```
