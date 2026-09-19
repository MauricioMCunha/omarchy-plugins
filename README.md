# Omarchy Plugins Lab

Monorepo para projetar, implementar e testar plugins e extensões locais do
Omarchy.

## Objetivos

- manter plugins do Omarchy separados da aplicação COMPASSO e do cofre;
- compartilhar padrões de UI, IPC, segurança e testes;
- permitir que novas extensões sejam adicionadas sem alterar
  `/usr/share/omarchy/`;
- instalar cada plugin em `~/.config/omarchy/plugins/` somente após validação.

## Primeiro projeto

`secure-input`: interface gráfica e integração segura para solicitações de
autorização privilegiada, com plugin Quickshell, broker local e helper
`sudo askpass`.

## Estrutura

```text
omarchy-plugins/
├── plugins/              # Plugins instaláveis do Omarchy
├── services/             # Brokers e serviços locais auxiliares
├── shared/               # Contratos e utilitários compartilhados
├── docs/                 # Decisões, segurança e operação
├── tests/                # Testes de integração e segurança
└── scripts/              # Build, validação e instalação controlada
```

## Regra de segurança

Nenhum plugin pode receber, registrar, persistir ou transmitir senhas. A UI
apenas solicita consentimento; qualquer operação privilegiada deve passar por
um componente local explicitamente delimitado, com contexto verificável,
timeout e uso único.

## Estado atual

O repositório contém apenas a estrutura inicial. O `secure-input` será
implementado primeiro em modo de teste, sem conexão com credenciais reais.
