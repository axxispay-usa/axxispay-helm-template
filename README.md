# axxispay-helm-template

Repositório do Helm chart genérico da Axxispay. Um único chart atende todas as aplicações — cada app configura apenas o que é específico dela via `values.yaml`.

## Repositório Helm

```bash
helm repo add axxispay https://axxispay-usa.github.io/axxispay-helm-template/
helm repo update
helm search repo axxispay
```

## Quick start

```bash
helm upgrade --install <app-name> axxispay/axxispay-helm-template \
  -f charts/axxispay/examples/<app-name>/values-homolog.yaml \
  --namespace <namespace> \
  --create-namespace
```

## Estrutura

```
.
├── charts/
│   └── axxispay/               # Helm chart
│       ├── Chart.yaml
│       ├── values.yaml         # valores padrão (base para todas as apps)
│       ├── templates/          # rollout, service, ingress, hpa, configmap, external-secret
│       └── examples/           # values por aplicação e ambiente
│           ├── values-reference.yaml
│           ├── axxis-bns-api/
│           ├── axxis-bns-bff/
│           ├── axxis-bns-ads/
│           └── axxis-bns-card/
├── .github/
│   └── workflows/
│       ├── release-please.yaml # abre PR de release automaticamente
│       ├── release.yaml        # empacota e publica no Helm repo
│       └── ci.yaml             # lint, template e package em todo PR
├── release-please-config.json
└── index.yaml                  # índice do repositório Helm (gh-pages)
```

## Documentação completa

Consulte [charts/axxispay/README.md](charts/axxispay/README.md) para:
- Por que Helm em vez de manifestos puros
- Como o nome da aplicação é definido
- Processo de release (release-please)
- Comandos de desenvolvimento local
- Tabela completa de values
- Requisitos do cluster
