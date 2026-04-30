# axxispay-helm-template

Helm chart genérico para todas as aplicações da Axxispay. Suporta múltiplas aplicações no mesmo namespace — o nome de todos os recursos Kubernetes é definido pelo `Release.Name` passado no `helm install`.

## Por que Helm em vez de manifestos puros?

Com manifestos YAML puros + ArgoCD, cada aplicação exige um conjunto de arquivos independentes. Qualquer mudança transversal — como adicionar um label, ajustar uma política de HPA ou trocar o provedor de secrets — precisa ser replicada manualmente em todos os repositórios. Isso gera inconsistência, aumenta o risco de erro humano e torna o onboarding de novas aplicações lento.

Com Helm + ArgoCD, a lógica vive em um único lugar e cada aplicação só descreve o que é específico dela:

| | Manifestos puros | Helm chart genérico |
|---|---|---|
| **Onboarding de nova app** | Copiar e adaptar todos os YAMLs | Criar um `values.yaml` com ~20 linhas |
| **Mudança transversal** | Editar N repositórios | Editar 1 template, todas as apps recebem |
| **Ambientes (homolog/prod)** | Arquivos duplicados ou Kustomize overlay | `values-homolog.yaml` e `values-prod.yaml` com apenas os overrides |
| **Consistência** | Depende de disciplina manual | Garantida pelo template — padrões são herdados |
| **Rollback** | `kubectl apply` de uma revisão anterior | `helm rollback <release> <revision>` |
| **Histórico de releases** | Apenas git history | `helm history <release>` com status de cada deploy |
| **Diff antes de aplicar** | `kubectl diff` limitado | `helm diff upgrade` mostra exatamente o que vai mudar |
| **Validação local** | Nenhuma sem cluster | `helm template` + `helm lint` sem precisar de cluster |

### No contexto da Axxispay

- Uma nova aplicação entra em produção adicionando apenas uma pasta em `examples/` com dois arquivos de values — sem tocar nos templates.
- Atualizações de segurança (ex: novo `ssl-policy` do ALB, novo campo no `securityContext`) são aplicadas em um único commit e propagadas para todas as apps no próximo sync do ArgoCD.
- O ArgoCD continua sendo a fonte de verdade para o estado do cluster — o Helm atua apenas como motor de template, sem conflito entre as ferramentas.

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
