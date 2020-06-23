# gcloud-kubectl-helm
Docker image for the quaternity of [gcloud](https://cloud.google.com/sdk/docs/), [helm](https://www.helm.sh), [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/) and [SOPS](https://github.com/mozilla/sops).

The image also contains:
* [cloud_sql_proxy](https://github.com/GoogleCloudPlatform/cloudsql-proxy)
* [gnupg](https://pkgs.alpinelinux.org/package/edge/main/x86_64/gnupg)
* [kubeval](https://github.com/instrumenta/kubeval)
* [mysql-client](https://pkgs.alpinelinux.org/package/edge/main/x86_64/mysql-client)
* [yq](https://github.com/mikefarah/yq)

## Command file examples

Authorize access to GCP with a service account and fetch credentials for running cluster
```bash
gcloud auth activate-service-account --key-file=/data/gcp-key-file.json
gcloud container clusters get-credentials <clusterName> --project <projectId> [--region=<region> | --zone=<zone>]

helm list
kubectl get pods --all-namespaces
```

## Import GPG Keys

To import public GPG keys from keyserver, add them space separated to GPG_PUB_KEYS env variable.

```bash
docker run -e GPG_PUB_KEYS=<key id>   kiwigrid/gcloud-kubectl-helm:latest
```

## Add distributed Helm Chart Repositories

To include adding of distributed helm chart repos, add REPO_YAML_URL as env variable.
E.g.

```bash
docker run -e REPO_YAML_URL=https://raw.githubusercontent.com/helm/hub/master/config/repo-values.yaml kiwigrid/gcloud-kubectl-helm:latest
```