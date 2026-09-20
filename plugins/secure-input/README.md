# secure-input

Plugin Omarchy para autorização gráfica de comandos privilegiados.

## Componentes

- `Panel.qml` e `SecureOverlay.qml`: widget e modal seguro do Quickshell;
- `services/secure_input_broker/broker.py`: serviço local e protocolo;
- `services/secure_input_broker/askpass.py`: helper compatível com sudo;
- `services/secure_input_broker/bridge.py`: bridge sem segredo em argumentos;
- `tests/`: testes sem credenciais reais.

O contrato completo está em [`../../openspec/secure-input.md`](../../openspec/secure-input.md).
