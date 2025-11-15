#!/bin/bash

# Exemplo de testes manuais para o Rate Limiter

echo "=== Rate Limiter - Testes Manuais ==="
echo ""

BASE_URL="http://localhost:8080"

echo "1. Testando health check..."
curl -s "$BASE_URL/health"
echo ""

echo "2. Testando rate limit por IP..."
echo "   Fazendo várias requisições rápidas para atingir o limite..."

# Primeiro, fazer algumas requisições para "aquecer" o rate limit
for i in {1..10}; do
  curl -s "$BASE_URL/test" > /dev/null
done

echo "   ⚡ Fazendo requisições rápidas para forçar rate limit..."
for i in {1..20}; do
  echo -n "Request $i: "
  response=$(curl -s -w "%{http_code}" --connect-timeout 1 --max-time 1 "$BASE_URL/test")
  http_code="${response: -3}"
  
  if [ "$http_code" = "200" ]; then
    echo "✅ OK"
  elif [ "$http_code" = "429" ]; then
    echo "🚫 RATE LIMITED! (Limite atingido)"
    echo "   Resposta: $(echo "$response" | sed 's/...$//')"
    break
  else
    echo "❌ Error: $http_code"
  fi
done

echo ""
echo "3. Testando rate limit com token..."
echo "   Token tem limite mais alto (100 req/s), precisa de muitas requisições..."

# Como o limite do token é 100 req/s, vamos fazer muitas requisições rápidas
echo "   ⚡ Fazendo 120 requisições rápidas com token..."
count_success=0
count_limited=0

for i in {1..120}; do
  response=$(curl -s -w "%{http_code}" --connect-timeout 1 --max-time 1 -H "API_KEY: abc123" "$BASE_URL/test" 2>/dev/null)
  http_code="${response: -3}"
  
  if [ "$http_code" = "200" ]; then
    count_success=$((count_success + 1))
  elif [ "$http_code" = "429" ]; then
    count_limited=$((count_limited + 1))
    if [ $count_limited -eq 1 ]; then
      echo "   🚫 RATE LIMITED! (Token limit atingido na requisição $i)"
      echo "   Resposta: $(echo "$response" | sed 's/...$//')"
    fi
  fi
  
  # Mostrar progresso a cada 10 requisições
  if [ $((i % 10)) -eq 0 ]; then
    echo "   Progresso: $i/120 (Sucesso: $count_success, Limitadas: $count_limited)"
  fi
done

echo "   ✅ Sucesso: $count_success"
echo "   🚫 Limitadas: $count_limited"

echo ""
echo "4. Testando endpoints da API..."
echo -n "GET /api/v1/users: "
curl -s -w "%{http_code}" "$BASE_URL/api/v1/users" | tail -c 3
echo ""

echo -n "GET /api/v1/data: "
curl -s -w "%{http_code}" "$BASE_URL/api/v1/data" | tail -c 3
echo ""

echo ""
echo "5. Testando headers de rate limit..."
echo "Headers retornados:"
curl -I "$BASE_URL/test" 2>/dev/null | grep -i rate-limit

echo ""
echo "=== Testes concluídos ==="