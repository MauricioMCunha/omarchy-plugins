# Omarchy Plugins Lab

Plugins Quickshell para o Omarchy, com foco em integração nativa, UX mínima,
segurança local e desenvolvimento reproduzível.

## Primeiro plugin: Doorman

`doorman` exibe uma solicitação gráfica para autorizar operações
privilegiadas iniciadas por uma sessão local. Ele combina:

- widget de topbar com tooltip nativo do Omarchy;
- modal Quickshell com foco automático e fluxo por teclado;
- broker local em socket Unix;
- integração limitada com `sudo askpass`;
- métricas de sessão e expiração de solicitações;
- especificação OpenSpec e testes automatizados.

O plugin não captura teclado global, clipboard, PTY ou comandos arbitrários.

## Segurança

O desenho atual usa:

- socket Unix em diretório privado (`0700`) e socket privado (`0600`);
- token de sessão e capability de origem;
- `request_id` e nonce criptograficamente aleatórios;
- uso único, expiração e cancelamento autenticado;
- validação de PID, UID, horário de início e linha de comando do processo;
- segredo fora de argumentos, arquivos persistentes, logs e clipboard;
- `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict` e `UMask=0077`;
- leitura do material de sessão diretamente do runtime privado, sem exportá-lo
  para o ambiente do processo `sudo`.

O fluxo usa o mecanismo oficial `sudo -A`/`SUDO_ASKPASS`. O wrapper opcional
`scripts/doorman-sudo` altera o PATH somente dentro do processo filho;
o `sudo` do sistema não é substituído globalmente.

### Avaliação atual

A avaliação interna de maturidade de segurança é **78/100**. Esse número não é
uma probabilidade de segurança nem uma certificação: representa o estado atual
dos controles, testes e operação conhecidos neste repositório.

O projeto é adequado para beta privado e desenvolvimento local. Ainda não deve
ser apresentado como auditado ou seguro para produção sem revisão independente.

Pendências antes de uma publicação pública mais ampla:

1. testar instalação, remoção, rollback e atualização em uma conta limpa;
2. adicionar `qmllint`, CI de dependências e inspeção automatizada de segredos;
3. ampliar testes de integração com Quickshell, Omarchy e `sudo` real;
4. revisar o threat model e o ciclo de vida do plugin com outra pessoa;
5. documentar o procedimento completo de instalação e recuperação.

## Validação

Execute:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
python3 -m py_compile services/doorman_broker/*.py plugins/doorman/*.py
git diff --check
```

O conjunto atual cobre autenticação, origem inválida, PID ausente, expiração,
aprovação, replay, nonce incorreto, cancelamento, askpass e alteração de
identidade do processo.

## Desenvolvimento local

Para testar o fluxo controlado de `sudo`:

```bash
scripts/doorman-run -- sudo id
```

O broker é executado como serviço `systemd --user`. A instalação do serviço e
do plugin deve ser explícita; o projeto não altera `/usr/share/omarchy/` nem
instala componentes silenciosamente.

## Estrutura

```text
omarchy-plugins/
├── plugins/              # Plugins instaláveis do Omarchy
├── services/             # Broker e serviços locais auxiliares
├── openspec/             # Especificações normativas
├── docs/                 # Arquitetura, segurança e operação
├── tests/                # Testes do broker e do askpass
└── scripts/              # Execução e integração local
```

## Documentação

- [OpenSpec do Doorman](openspec/doorman.md)
- [Arquitetura](docs/architecture.md)
- [Modelo de segurança](docs/security.md)
- [Revisão para publicação](docs/publishing-security.md)
- [Graphify](graphify-out/graph.json)

## Licença

MIT. Consulte [LICENSE](LICENSE).
