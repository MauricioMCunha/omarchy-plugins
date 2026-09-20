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

O `secure-input` possui broker Unix, helper `sudo askpass`, bridge para a UI,
plugin Quickshell, unit `systemd --user` e testes sem credenciais reais. A
especificação normativa está em [`openspec/secure-input.md`](openspec/secure-input.md).
O fluxo exige `sudo -A` quando o processo tem um TTY. `SUDO_ASKPASS` pode ser
configurado sem substituir `sudo` nem alterar `sudoers`, mas nesta versão do
sudo isso não elimina a necessidade de `-A` em processos interativos. O
wrapper `scripts/secure-input-sudo` existe apenas como opção explícita para
uma sessão controlada que precisa transformar `sudo comando` em askpass.

Para executar um processo de LLM nesse modo controlado, use:

```bash
scripts/secure-input-run -- seu-comando-da-llm
```

O `sudo` é sombreado apenas dentro desse processo filho; o PATH do usuário e
o `/usr/bin/sudo` permanecem inalterados.
