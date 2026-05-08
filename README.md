# axxispay-helm-template

Repositório do Helm chart genérico da Axxispay. Um único chart atende todas as aplicações — cada app configura apenas o que é específico dela via `values.yaml`.

## Instalação via OCI

```bash
# Helm >= 3.8
helm install <app-name> oci://ghcr.io/axxispay-usa/axxispay-helm-template \
  --version <version> \
  -f my-values.yaml \
  --namespace <namespace> \
  --create-namespace
```

## Quick start

```bash
helm upgrade --install <app-name> oci://ghcr.io/axxispay-usa/axxispay-helm-template \
  --version <version> \
  -f charts/axxispay/examples/axxis-bns-api/values-homolog.yaml \
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
│       ├── templates/          # rollout, rollout-preview, service, service-preview,
│       │                       # ingress, hpa, configmap, configmap-preview,
│       │                       # external-secret, service-account
│       └── examples/           # values de referência por aplicação
│           ├── values-reference.yaml
│           ├── axxis-bns-ads/
│           ├── axxis-bns-api/
│           ├── axxis-bns-bff/
│           └── axxis-bns-card/
├── .github/
│   └── workflows/
│       ├── release-please.yaml # abre PR de release automaticamente
│       ├── release.yaml        # empacota e publica no GHCR (OCI)
│       └── ci.yaml             # lint, template e package em todo PR
└── release-please-config.json
```

## Documentação completa

Consulte [charts/axxispay/README.md](charts/axxispay/README.md) para:
- Por que Helm em vez de manifestos puros
- Como o nome da aplicação é definido
- Processo de release (release-please)
- Comandos de desenvolvimento local
- Tabela completa de values
- Requisitos do cluster
