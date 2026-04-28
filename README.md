# axxis-app-bff Helm Chart

Helm chart migrado a partir dos manifests Kustomize do serviço `axxis-app-bff`.

## Estrutura

```
axxis-app-bff/
├── Chart.yaml
├── values.yaml              # valores padrão
├── values-homolog.yaml      # overrides para homolog
├── values-prod.yaml         # overrides para produção
└── templates/
    ├── _helpers.tpl
    ├── rollout.yaml         # Argo Rollout (canary)
    ├── service.yaml
    ├── ingress.yaml         # AWS ALB Ingress
    ├── hpa.yaml             # HPA v2 (autoscaling por memória)
    ├── configmap.yaml
    └── external-secret.yaml # External Secrets Operator
```

## Uso

### Homolog
```bash
helm upgrade --install axxis-app-bff . \
  -f values-homolog.yaml \
  --namespace bns \
  --create-namespace
```

### Produção
```bash
helm upgrade --install axxis-app-bff . \
  -f values-prod.yaml \
  --set image.tag=<GIT_SHA> \
  --namespace bns
```

### ArgoCD (Application)
```yaml
source:
  repoURL: <seu-repo>
  targetRevision: HEAD
  path: charts/axxis-app-bff
  helm:
    valueFiles:
      - values-homolog.yaml
    parameters:
      - name: image.tag
        value: $ARGOCD_APP_REVISION
```

## Principais Values

| Key | Descrição | Default |
|-----|-----------|---------|
| `image.tag` | Tag da imagem ECR | `homolog` |
| `hpa.minReplicas` | Mínimo de réplicas | `1` |
| `hpa.maxReplicas` | Máximo de réplicas | `3` |
| `rollout.strategy.canary.maxSurge` | Surge do canary | `25%` |
| `externalSecret.dataFrom[0].extract.key` | Chave no AWS Secrets Manager | `bns/bns-bff` |
| `ingress.enabled` | Habilitar ingress ALB | `true` |
