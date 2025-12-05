Please follow belo steps to install wiz in AKS cluster.

helm repo add wiz-sec https://charts.wiz.io
helm repo update
kubectl create namespace wiz
kubectl -n wiz create secret generic wiz-api-token --from-literal clientId=***** --from-literal clientToken=****
helm upgrade wiz-integration wiz-sec/wiz-kubernetes-integration --values values.yaml -n wiz