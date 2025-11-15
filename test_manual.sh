#!/bin/bash

# Exemplo de testes manuais para o Rate Limiter

echo "=== Rate Limiter - Testes Manuais ==="
echo ""

BASE_URL="http://localhost:8080"

echo "1. Testando health check..."
curl -s "$BASE_URL/health" | jq '.'
echo ""

echo "2. Testando rate limit por IP (fazendo 15 requisições)..."
for i in {1..15}; do
  echo -n "Request $i: "
  response=$(curl -s -w "%{http_code}" "$BASE_URL/test")
  http_code="${response: -3}"
  body="${response%???}"
  
  if [ "$http_code" = "200" ]; then
    echo "✅ OK"
  elif [ "$http_code" = "429" ]; then
    echo "🚫 Rate limited"
    break
  else
    echo "❌ Error: $http_code"
  fi
  
  sleep 0.1
done

echo ""
echo "3. Testando rate limit por token (fazendo 15 requisições com API_KEY)..."
for i in {1..15}; do
  echo -n "Request $i (with token): "
  response=$(curl -s -w "%{http_code}" -H "API_KEY: test-token-123" "$BASE_URL/test")
  http_code="${response: -3}"
  body="${response%???}"
  
  if [ "$http_code" = "200" ]; then
    echo "✅ OK"
  elif [ "$http_code" = "429" ]; then
    echo "🚫 Rate limited"
    break
  else
    echo "❌ Error: $http_code"
  fi
  
  sleep 0.1
done

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