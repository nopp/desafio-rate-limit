# Rate Limiter em Go

Um sistema de controle de tráfego que limita requisições por IP ou token de acesso.

## 🚀 Início Rápido

```bash
# Executar demo completa (recomendado)
make dev

# Ou executar manualmente
make docker-up
make test-manual
```

## 📝 Como Funciona

- **Por IP**: Máximo 10 requisições/segundo (bloqueia por 5 minutos se exceder)
- **Por Token**: Máximo 100 requisições/segundo (bloqueia por 10 minutos se exceder)
- **Header**: `API_KEY: seu-token` (token tem prioridade sobre IP)
- **Resposta**: HTTP 429 quando limite excedido

## 🔧 Configuração (Opcional)

Edite o arquivo `.env` para alterar os limites:

```bash
IP_RATE_LIMIT=10           # Requisições por segundo por IP  
TOKEN_RATE_LIMIT=100       # Requisições por segundo por token
IP_BLOCK_DURATION=300      # Bloqueio IP (segundos)
TOKEN_BLOCK_DURATION=600   # Bloqueio token (segundos)
```

## 💡 Exemplos de Uso

```bash
# Requisição normal (sem token)
curl http://localhost:8080/test

# Requisição com token (limite maior)
curl -H "API_KEY: meu-token" http://localhost:8080/test

# Testar até atingir limite
for i in {1..15}; do curl http://localhost:8080/test; done
```

## 🔗 Endpoints

- `GET /health` - Status da aplicação
- `GET /test` - Endpoint para testes
- `GET /api/v1/users` - Lista de usuários
- `GET /api/v1/data` - Dados de exemplo

## 🚫 Resposta de Bloqueio

```json
HTTP/1.1 429 Too Many Requests
{
  "message": "you have reached the maximum number of requests or actions allowed within a certain time frame"
}
```

## 🛠️ Comandos Úteis

```bash
make help          # Lista todos os comandos
make test          # Executa testes
make build         # Compila a aplicação
make docker-up     # Inicia com Docker
make docker-down   # Para containers
```