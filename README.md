# axxispay-helm-template

Helm chart genérico para todas as aplicações da Axxispay. Suporta múltiplas aplicações no mesmo namespace — o nome de todos os recursos Kubernetes é definido pelo `Release.Name` passado no `helm install`.

## Estrutura

```
axxispay-helm-template/
├── Chart.yaml
├── values.yaml                     # valores padrão (base para todas as apps)
├── templates/
│   ├── _helpers.tpl                # funções auxiliares (fullname, labels)
│   ├── rollout.yaml                # Argo Rollout com estratégia canary
│   ├── service.yaml                # Service ClusterIP
│   ├── ingress.yaml                # Ingress AWS ALB
│   ├── hpa.yaml                    # HorizontalPodAutoscaler v2
│   ├── configmap.yaml              # ConfigMap com variáveis não sensíveis
│   └── external-secret.yaml        # ExternalSecret (AWS Secrets Manager via ESO)
└── examples/
    ├── values-reference.yaml       # referência completa de todos os campos
    ├── axxis-bns-bff/
    │   ├── values-homolog.yaml
    │   └── values-prod.yaml
    ├── axxis-bns-api/
    │   ├── values-homolog.yaml
    │   └── values-prod.yaml
    ├── axxis-bns-ads/
    │   ├── values-homolog.yaml
    │   └── values-prod.yaml
    └── axxis-bns-card/
        ├── values-homolog.yaml
        └── values-prod.yaml
```

## Como o nome da aplicação é definido

O `Release.Name` (primeiro argumento do `helm install`) nomeia todos os recursos criados:

```bash
helm upgrade --install axxis-bns-bff .
# Cria: Rollout/axxis-bns-bff, Service/axxis-bns-bff, Ingress/axxis-bns-bff,
#        HPA/axxis-bns-bff, ConfigMap/axxis-bns-bff, ExternalSecret/axxis-bns-bff
```

## Deploy

### Homolog

```bash
helm upgrade --install <app-name> axxispay/helm-template \
  -f examples/<app-name>/values-homolog.yaml \
  --namespace bns \
  --create-namespace
```

### Produção

```bash
helm upgrade --install <app-name> axxispay/helm-template \
  -f examples/<app-name>/values-prod.yaml \
  --set image.tag=$(git rev-parse --short HEAD) \
  --namespace bns
```

### Exemplos por aplicação

```bash
# axxis-bns-bff
helm upgrade --install axxis-bns-bff axxispay/helm-template \
  -f examples/axxis-bns-bff/values-homolog.yaml --namespace bns

# axxis-bns-api
helm upgrade --install axxis-bns-api axxispay/helm-template \
  -f examples/axxis-bns-api/values-homolog.yaml --namespace bns

# axxis-bns-ads
helm upgrade --install axxis-bns-ads axxispay/helm-template \
  -f examples/axxis-bns-ads/values-homolog.yaml --namespace bns

# axxis-bns-card
helm upgrade --install axxis-bns-card axxispay/helm-template \
  -f examples/axxis-bns-card/values-homolog.yaml --namespace bns
```

## ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: axxis-bns-bff
  namespace: argocd
spec:
  destination:
    namespace: bns
    server: https://kubernetes.default.svc
  source:
    repoURL: <helm-repo-url>
    chart: axxispay/helm-template
    targetRevision: 0.1.0
    helm:
      releaseName: axxis-bns-bff
      valueFiles:
        - examples/axxis-bns-bff/values-homolog.yaml
      parameters:
        - name: image.tag
          value: $ARGOCD_APP_REVISION
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Principais Values

| Key | Descrição | Default |
|-----|-----------|---------|
| `image.repository` | Repositório ECR da imagem | — |
| `image.tag` | Tag da imagem (usar git SHA em prod) | `homolog` |
| `image.pullPolicy` | Política de pull | `Always` |
| `containerPort` | Porta exposta pelo container | `8080` |
| `rollout.enabled` | Habilitar Argo Rollout | `true` |
| `rollout.strategy.canary.maxSurge` | Surge do canary | `25%` |
| `rollout.strategy.canary.steps` | Steps do canary (opcional) | `[]` |
| `hpa.enabled` | Habilitar HPA | `true` |
| `hpa.minReplicas` | Mínimo de réplicas | `1` |
| `hpa.maxReplicas` | Máximo de réplicas | `3` |
| `ingress.enabled` | Habilitar ingress ALB | `true` |
| `ingress.hosts[].host` | Hostname do ingress | — |
| `ingress.hosts[].serviceName` | Service de destino (padrão: Release.Name) | — |
| `configmap.enabled` | Habilitar ConfigMap | `true` |
| `configmap.data` | Variáveis de ambiente não sensíveis | `{}` |
| `externalSecret.enabled` | Habilitar ExternalSecret | `true` |
| `externalSecret.refreshInterval` | Intervalo de sync com Secrets Manager | `30s` |
| `externalSecret.dataFrom[].extract.key` | Chave no AWS Secrets Manager | — |
| `reloader.enabled` | Reiniciar pods ao mudar ConfigMap/Secret | `true` |

## Requisitos

| Componente | Versão mínima |
|------------|---------------|
| Helm | 3.x |
| Argo Rollouts | 1.x |
| External Secrets Operator | 0.10+ |
| AWS Load Balancer Controller | 2.x |
| Stakater Reloader | 1.x |
