# ADR 0001 — Monorepo para plugins do Omarchy

## Decisão

Manter plugins e serviços auxiliares em um projeto separado em `~/DEV`, com
cada plugin isolado em `plugins/` e componentes privilegiados em `services/`.

## Motivo

O repositório do COMPASSO não é o local correto para código de desktop. O
monorepo permite compartilhar contratos e testes sem misturar dependências,
deploy web ou dados do cofre.

## Consequência

Cada plugin terá seu próprio ciclo de teste e instalação. A instalação na
sessão Omarchy será uma etapa explícita e reversível.
