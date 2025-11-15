#!/bin/bash

echo "🚀 RATE LIMITER - TESTE INTENSIVO"
echo "================================="
echo ""

echo "📋 Fazendo 25 requisições MUITO RÁPIDAS para forçar rate limit..."
echo ""

# Fazer requisições muito rápidas para atingir o limite
for i in {1..25}; do
    echo -n "Req $i: "
    
    # Fazer requisição sem delay
    status_code=$(curl -s -w '%{http_code}' -o /tmp/response.json --connect-timeout 1 --max-time 1 http://localhost:8080/test)
    
    if [ "$status_code" = "200" ]; then
        echo "✅ OK"
    elif [ "$status_code" = "429" ]; then
        echo "🚫 RATE LIMITED!"
        echo "   Resposta: $(cat /tmp/response.json 2>/dev/null)"
        echo "   🎯 Rate limit funcionando! Parando teste aqui."
        break
    else
        echo "❌ Erro: $status_code"
    fi
done

echo ""
echo "📋 Testando com múltiplas requisições simultâneas..."

# Fazer requisições em paralelo para forçar o rate limit
{
    for i in {1..15}; do
        curl -s http://localhost:8080/test &
    done
    wait
} > /dev/null 2>&1

echo "✅ 15 requisições simultâneas enviadas!"
echo ""

echo "📋 Verificando se alguma foi bloqueada..."
status_code=$(curl -s -w '%{http_code}' -o /tmp/response.json http://localhost:8080/test)
if [ "$status_code" = "429" ]; then
    echo "🚫 SUCESSO! Rate limit ativado:"
    echo "   Status: $status_code"
    echo "   Mensagem: $(cat /tmp/response.json 2>/dev/null)"
else
    echo "✅ Requisição ainda permitida: $status_code"
fi

echo ""
echo "📊 Headers de Rate Limit atuais:"
curl -I http://localhost:8080/test 2>/dev/null | grep -i "x-ratelimit" | while read line; do
    echo "   $line"
done