# Helm-CI

(Forked from https://github.com/mf-lit/helm-ci)

## Introduction

A docker image for running helm/kubectl with certificates encrypted using AWS KMS

We deploy to kubernetes from our CircleCI pipeline and needed a way to allow helm (and kubectl) to run in that pipeline.

EKS using eks-iam-authenticator is supported

We also bundle the qa-housekeeper into this image
----

## How to build

There is no pipeline for this (deliberately as it's so simple).

Edit the Dockerfile (choosing the versions of kubectl, helm and sops that you want to bundle in)

kubectl version skew policy: https://kubernetes.io/docs/setup/release/version-skew-policy/
helm version skew policy: https://helm.sh/docs/topics/version_skew/

Build and push the docker image:

```
docker build -t 310555233936.dkr.ecr.eu-west-1.amazonaws.com/helm-ci:<tag> .
ecrlogin
docker push 310555233936.dkr.ecr.eu-west-1.amazonaws.com/helm-ci:<tag>
```

All our pipelines will pull the default `latest` tag of the image. So once you push that tag, you are effectively putting the image into production everywhere (which is great!)

If you want to test it in a pipeline first, create a version tag (e.g. 310555233936.dkr.ecr.eu-west-1.amazonaws.com/helm-ci:3.0.2) and then temporarily modify a pipeline to use that tag. Once you've tested you can then tag and push `latest`

## Included scripts

`entrypoint.sh`
A simple docker entrypoint script, it sets up EKS authentication and then passes through the docker command. That's it (it used to be a lot more complicated in the Helm 2 days)

`helm3-bc.sh`
This is a wrapper script, symlinked to /usr/bin/helm.

Most of our pipelines used helm2 originally, which required the `--tls` switch. The `--tls` switch was deprecated in helm3, so this script strips it out if it exists, and then passes all remaining arguments to /usr/bin/helm3. Once all our pipelines are updated, this script will no longer be needed.

`qa-housekeeper.sh`
The QA housekeeper is not needed for (and indeed has nothing to do with) our CI/CD pipelines, but it made sense to bundle it into this image.

QA Housekeeper runs as a cronjob in the QA enviroment, deleting releases that haven't been built for N days or have had their Pull Request closed.

See:

https://github.com/CarePlanner/careplanner/blob/317650007f038500698aaa7b19337cdf0ff29f57/.circleci/config.yml#L252
https://github.com/CarePlanner/confman/tree/master/helm/charts/qa-housekeeper
https://github.com/CarePlanner/confman/blob/master/helm/deploy/qa/helmfile.d/qa-housekeeper.yaml

