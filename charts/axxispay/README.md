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
helm upgrade --install my-app .
# Cria: Rollout/my-app, Service/my-app, Ingress/my-app,
#        HPA/my-app, ConfigMap/my-app, ExternalSecret/my-app
```

## Publicando uma nova versão

O processo de release é totalmente automatizado via dois workflows:

```
commit (feat/fix) → push main → release-please abre PR → merge PR → GitHub Release criada
                                                                            ↓
                                                               release.yaml empacota o chart
                                                               e publica no gh-pages (Helm repo)
```

### Workflows

| Arquivo | Gatilho | Responsabilidade |
|---|---|---|
| `release-please.yaml` | push em `main` | Lê commits, abre/atualiza PR de release com versão bumped e CHANGELOG |
| `release.yaml` | GitHub Release publicada | Empacota o chart e publica no repositório Helm (gh-pages) |

### Como funciona na prática

Use o padrão [Conventional Commits](https://www.conventionalcommits.org/) nas mensagens de commit:

| Prefixo | Efeito na versão | Exemplo |
|---|---|---|
| `fix:` | patch `0.1.0 → 0.1.1` | `fix: corrige porta do healthcheck` |
| `feat:` | minor `0.1.0 → 0.2.0` | `feat: adiciona suporte a blue-green` |
| `feat!:` ou `BREAKING CHANGE` | major `0.1.0 → 1.0.0` | `feat!: remove suporte a Deployment` |
| `chore:`, `docs:`, `refactor:` | sem release | `docs: atualiza README` |

O release-please acumula os commits e abre um PR como este:

```
chore: release 0.2.0

- feat: adiciona suporte a blue-green strategy
- fix: corrige indentação no configmap
```

Ao mergear esse PR, a GitHub Release é criada automaticamente e o `release.yaml` publica o chart.

### Configuração necessária no GitHub (uma única vez)

- `Settings → Pages → Source`: branch `gh-pages`, pasta `/root`
- `Settings → Actions → General → Workflow permissions`: `Read and write permissions`

### Via comando (release manual)

```bash
VERSION=1.6.1
curl -sSL "https://github.com/helm/chart-releaser/releases/download/v${VERSION}/chart-releaser_${VERSION}_linux_amd64.tar.gz" \
  | tar -xz cr && sudo mv cr /usr/local/bin/cr

cr package .
cr upload --owner <org> --git-repo <repo> --token <GITHUB_TOKEN>
cr index  --owner <org> --git-repo <repo> --token <GITHUB_TOKEN> \
          --pages-branch gh-pages --push
```

### Adicionando o repositório no Helm

```bash
helm repo add axxispay https://<org>.github.io/<repo>
helm repo update
helm search repo axxispay
```

## Desenvolvimento local

Comandos úteis para validar o chart antes de fazer push:

```bash
# Verifica erros de sintaxe e boas práticas
helm lint charts/axxispay

# Renderiza os manifests sem aplicar no cluster (dry-run)
helm template my-app charts/axxispay \
  --set image.repository=placeholder/my-app \
  --set namespace=bns \
  --set ingress.annotations."alb\.ingress\.kubernetes\.io/certificate-arn"=arn:fake \
  --set ingress.annotations."alb\.ingress\.kubernetes\.io/group\.name"=axxis-app \
  --set ingress.annotations."alb\.ingress\.kubernetes\.io/load-balancer-name"=my-app \
  --set externalSecret.secretStoreRef.name=bns-apps

# Renderiza usando um values file de exemplo
helm template my-app charts/axxispay -f examples/axxis-bns-api/values-homolog.yaml

# Empacota o chart em um .tgz
helm package charts/axxispay

# Gera o index.yaml para o repositório Helm
helm repo index . --url https://github.com/<org>/<repo>

# Verifica o diff antes de aplicar em um cluster (requer helm-diff plugin)
helm diff upgrade my-app axxispay/helm-template -f examples/axxis-bns-api/values-homolog.yaml
```

> Os workflows de CI executam `lint`, `template` e `package` automaticamente em todo PR e push para `main`.

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
  name: <app-name>
  namespace: argocd
spec:
  destination:
    namespace: <namespace>
    server: https://kubernetes.default.svc
  source:
    repoURL: <helm-repo-url>
    chart: axxispay/helm-template
    targetRevision: 0.1.0
    helm:
      releaseName: <app-name>
      valueFiles:
        - examples/<app-name>/values-homolog.yaml
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
