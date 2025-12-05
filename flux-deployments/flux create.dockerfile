az k8s-configuration flux create \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name wiz-k8s-integration \
  --namespace wiz \
  --cluster-type managedClusters \
  --sync-interval 10m \
  --scope cluster
  --url https://github.com/<your-org>/<your-repo> \
  --branch main \
  --kustomization name=infrastructure \
    path=./flux-deployments/infrastructure/overlays/dev \
    prune=true \
  --https-user accountname --https-key accounttoken