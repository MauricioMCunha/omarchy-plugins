# Secure Input Broker

Protótipo local do broker para o plugin `secure-input`.

## Executar

```bash
python3 -m services.secure_input_broker.broker --socket /tmp/omarchy-secure-input.sock
```

O broker não possui UI própria. O comando `ui_test.py` simula a futura
interface Quickshell e deve ser usado somente com segredos fictícios.

## Limites do protótipo

- socket Unix local com modo `0600`;
- token de sessão obrigatório;
- nonce e request id por solicitação;
- autorização de uso único com timeout;
- nenhum log do valor secreto;
- sem integração com `sudo` real nesta fase.
