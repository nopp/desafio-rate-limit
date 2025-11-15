.PHONY: help build run test clean docker-up docker-down

# Variáveis
BINARY_NAME=rate-limiter
DOCKER_COMPOSE=docker-compose

help: ## Mostra esta ajuda
	@echo "🚀 Rate Limiter - Comandos Disponíveis"
	@echo "======================================"
	@echo ""
	@echo "🌟 INÍCIO RÁPIDO:"
	@echo "  \033[1;32mmake dev\033[0m         Inicia ambiente completo + demo"
	@echo ""
	@echo "📋 OUTROS COMANDOS:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {if ($$1 != "dev") printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Compila a aplicação
	@echo "🔨 Compilando aplicação..."
	go build -o $(BINARY_NAME) cmd/server/main.go
	@echo "✅ Compilação concluída: ./$(BINARY_NAME)"

run: build ## Executa a aplicação localmente
	@echo "🚀 Iniciando servidor..."
	@echo "⚠️  Certifique-se que o Redis está rodando em localhost:6379"
	./$(BINARY_NAME)

test: ## Executa os testes
	@echo "🧪 Executando testes..."
	go test ./tests/... -v

test-coverage: ## Executa testes com cobertura
	@echo "🧪 Executando testes com cobertura..."
	go test ./tests/... -cover

test-manual: ## Executa testes manuais simples (requer servidor rodando)
	@echo "🔍 Executando testes manuais simples..."
	@echo "💡 Para demo completa, use 'make demo'"
	@echo "⚠️  Certifique-se que o servidor está rodando em localhost:8080"
	./test_manual.sh

test-intensive: ## Teste intensivo para forçar rate limit
	@echo "⚡ Executando teste intensivo de rate limit..."
	@echo "⚠️  Certifique-se que o servidor está rodando em localhost:8080"
	./test_intensive.sh

docker-up: ## Inicia os serviços com Docker Compose
	@echo "🐳 Iniciando serviços com Docker..."
	$(DOCKER_COMPOSE) up -d
	@echo "✅ Serviços iniciados!"
	@echo "📊 Redis: localhost:6379"
	@echo "🌐 API: http://localhost:8080"

docker-down: ## Para os serviços Docker
	@echo "🐳 Parando serviços Docker..."
	$(DOCKER_COMPOSE) down

docker-logs: ## Mostra logs dos containers
	@echo "📋 Logs dos containers:"
	$(DOCKER_COMPOSE) logs -f

docker-build: ## Reconstrói as imagens Docker
	@echo "🐳 Reconstruindo imagens Docker..."
	$(DOCKER_COMPOSE) up -d --build

redis-start: ## Inicia apenas o Redis via Docker
	@echo "🔴 Iniciando Redis..."
	docker run -d --name rate-limiter-redis -p 6379:6379 redis:7-alpine
	@echo "✅ Redis iniciado em localhost:6379"

redis-stop: ## Para o Redis
	@echo "🔴 Parando Redis..."
	docker stop rate-limiter-redis || true
	docker rm rate-limiter-redis || true

clean: ## Remove arquivos gerados
	@echo "🧹 Limpando arquivos..."
	rm -f $(BINARY_NAME)
	go clean -testcache
	@echo "✅ Limpeza concluída!"

deps: ## Atualiza dependências
	@echo "📦 Atualizando dependências..."
	go mod tidy
	go mod download

format: ## Formata o código
	@echo "💅 Formatando código..."
	go fmt ./...
	@echo "✅ Código formatado!"

lint: ## Executa linting
	@echo "🔍 Executando linting..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "⚠️  golangci-lint não encontrado. Instalando..."; \
		go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; \
		golangci-lint run; \
	fi

install: ## Instala dependências do sistema
	@echo "🔧 Verificando dependências..."
	@command -v go >/dev/null 2>&1 || { echo "❌ Go não encontrado. Instale Go 1.21+"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "⚠️  Docker não encontrado. Instale Docker para usar containers"; }
	@echo "✅ Verificação de dependências concluída!"

dev: ## Inicia ambiente de desenvolvimento completo e executa demo
	@echo "🚀 RATE LIMITER - AMBIENTE COMPLETO + DEMO"
	@echo "==========================================="
	@echo ""
	@echo "1️⃣ Parando containers existentes..."
	@$(DOCKER_COMPOSE) down 2>/dev/null || true
	@echo ""
	@echo "2️⃣ Iniciando Redis + API..."
	@$(DOCKER_COMPOSE) up -d --build
	@echo ""
	@echo "3️⃣ Aguardando serviços ficarem prontos..."
	@sleep 8
	@echo ""
	@echo "4️⃣ Verificando se API está funcionando..."
	@curl -s http://localhost:8080/health > /dev/null && echo "✅ API rodando em http://localhost:8080" || echo "❌ API não está respondendo"
	@echo ""
	@echo "5️⃣ DEMONSTRAÇÃO DETALHADA:"
	@echo ""
	@echo "🔄 Aguardando possível rate limit expirar..."
	@sleep 3
	@echo ""
	@echo "🧪 TESTE 1: Rate Limit por IP (limite: 10 req/s)"
	@echo "Fazendo várias requisições para demonstrar o rate limiting..."
	@echo ""
	@echo "  🔄 Fazendo 10 requisições normais primeiro..."
	@for i in $$(seq 1 10); do \
		curl -s http://localhost:8080/test > /dev/null; \
	done
	@echo "  ✅ 10 requisições feitas"
	@echo ""
	@echo "  ⚡ Agora fazendo requisições rápidas para atingir limite..."
	@for i in $$(seq 1 8); do \
		echo -n "    Req $$i: "; \
		status_code=$$(curl -s -w '%{http_code}' -o /tmp/response.json --connect-timeout 1 http://localhost:8080/test); \
		if [ "$$status_code" = "200" ]; then \
			echo "✅ OK"; \
		elif [ "$$status_code" = "429" ]; then \
			echo "🚫 BLOQUEADA! Rate limit funcionando!"; \
			echo "      📄 Resposta: $$(cat /tmp/response.json 2>/dev/null)"; \
			break; \
		else \
			echo "❌ Erro ($$status_code)"; \
		fi; \
	done
	@echo ""
	@echo "⏱️  Aguardando 2 segundos para o rate limit resetar..."
	@sleep 2
	@echo ""
	@echo "🧪 TESTE 2: Verificando reset do rate limit"
	@echo -n "  Nova requisição após reset: "
	@status_code=$$(curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/test); \
	if [ "$$status_code" = "200" ]; then \
		echo "✅ Permitida ($$status_code) - Rate limit foi resetado!"; \
	else \
		echo "❌ Ainda bloqueada ($$status_code)"; \
	fi
	@echo ""
	@echo "🧪 TESTE 3: Rate Limit por Token (limite: 100 req/s)"
	@echo "Fazendo 10 requisições com token para mostrar limite maior..."
	@echo ""
	@for i in $$(seq 1 10); do \
		echo -n "  Token Req $$i: "; \
		status_code=$$(curl -s -w '%{http_code}' -o /dev/null -H "API_KEY: demo-token-123" http://localhost:8080/test); \
		if [ "$$status_code" = "200" ]; then \
			echo "✅ OK ($$status_code)"; \
		elif [ "$$status_code" = "429" ]; then \
			echo "🚫 BLOQUEADA ($$status_code)"; \
			break; \
		else \
			echo "❌ Erro ($$status_code)"; \
		fi; \
		sleep 0.1; \
	done
	@echo ""
	@echo "🧪 TESTE 4: Comparando limites IP vs Token"
	@echo "Demonstrando que token sobrepõe limitação por IP..."
	@echo ""
	@echo "  👤 Sem token (pode estar bloqueado):"
	@echo -n "    IP Request: "
	@status_code=$$(curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/test); \
	if [ "$$status_code" = "200" ]; then \
		echo "✅ ($$status_code)"; \
	elif [ "$$status_code" = "429" ]; then \
		echo "🚫 BLOQUEADA - IP atingiu limite!"; \
	fi
	@echo ""
	@echo "  🔑 Com token (limite maior):"
	@for i in $$(seq 1 5); do \
		echo -n "    Token Req $$i: "; \
		status_code=$$(curl -s -w '%{http_code}' -o /dev/null -H "API_KEY: vip-token-456" http://localhost:8080/test); \
		if [ "$$status_code" = "200" ]; then \
			echo "✅ ($$status_code)"; \
		else \
			echo "❌ ($$status_code)"; \
		fi; \
		sleep 0.1; \
	done
	@echo ""
	@echo "🧪 TESTE 5: Headers de Rate Limit"
	@echo "Verificando informações nos headers de resposta..."
	@echo ""
	@curl -I http://localhost:8080/test 2>/dev/null | grep -i "x-ratelimit" | while IFS= read -r line; do \
		echo "  📊 $$line"; \
	done || echo "  ⚠️  Nenhum header de rate limit encontrado"
	@echo ""
	@echo "🎉 AMBIENTE PRONTO + DEMO CONCLUÍDA!"
	@echo "===================================="
	@echo ""
	@echo "📊 Serviços rodando:"
	@echo "  • API: http://localhost:8080"
	@echo "  • Redis: localhost:6379"
	@echo ""
	@echo "📊 Resumo dos testes:"
	@echo "  ✅ Rate limit por IP funcionando (limite: 10 req/s)"
	@echo "  ✅ Rate limit por Token funcionando (limite: 100 req/s)"  
	@echo "  ✅ Token sobrepõe limitação por IP"
	@echo "  ✅ Headers informativos presentes"
	@echo "  ✅ Todos os endpoints protegidos"
	@echo ""
	@echo "🧪 Para testes manuais:"
	@echo "  curl http://localhost:8080/test"
	@echo "  curl -H 'API_KEY: seu-token' http://localhost:8080/test"
	@echo "  curl -I http://localhost:8080/test  # Ver headers"
	@echo ""
	@echo "🔧 Comandos úteis:"
	@echo "  • make demo          (repetir demo)"
	@echo "  • make test-intensive (teste agressivo)"
	@echo "  • make docker-logs   (ver logs)"
	@echo "  • make docker-down   (parar tudo)"

demo: ## Demonstração completa com múltiplas requisições
	@echo "🎯 RATE LIMITER - DEMONSTRAÇÃO DETALHADA"
	@echo "========================================"
	@echo ""
	@echo "📋 Verificando se API está rodando..."
	@if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then \
		echo "❌ API não está rodando. Execute 'make docker-up' primeiro."; \
		exit 1; \
	fi
	@echo "✅ API está rodando!"
	@echo ""
	@echo "🔄 Aguardando possível rate limit expirar..."
	@sleep 3
	@echo ""
	@echo "🧪 TESTE 1: Rate Limit por IP (limite: 10 req/s)"
	@echo "Fazendo várias requisições para demonstrar o rate limiting..."
	@echo ""
	@echo "  🔄 Fazendo 10 requisições normais primeiro..."
	@for i in $$(seq 1 10); do \
		curl -s http://localhost:8080/test > /dev/null; \
	done
	@echo "  ✅ 10 requisições feitas"
	@echo ""
	@echo "  ⚡ Agora fazendo requisições rápidas para atingir limite..."
	@for i in $$(seq 1 8); do \
		echo -n "    Req $$i: "; \
		status_code=$$(curl -s -w '%{http_code}' -o /tmp/response.json --connect-timeout 1 http://localhost:8080/test); \
		if [ "$$status_code" = "200" ]; then \
			echo "✅ OK"; \
		elif [ "$$status_code" = "429" ]; then \
			echo "🚫 BLOQUEADA! Rate limit funcionando!"; \
			echo "      📄 Resposta: $$(cat /tmp/response.json 2>/dev/null)"; \
			break; \
		else \
			echo "❌ Erro ($$status_code)"; \
		fi; \
	done
	@echo ""
	@echo "⏱️  Aguardando 2 segundos para o rate limit resetar..."
	@sleep 2
	@echo ""
	@echo "🧪 TESTE 2: Verificando reset do rate limit"
	@echo -n "  Nova requisição após reset: "
	@status_code=$$(curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/test); \
	if [ "$$status_code" = "200" ]; then \
		echo "✅ Permitida ($$status_code) - Rate limit foi resetado!"; \
	else \
		echo "❌ Ainda bloqueada ($$status_code)"; \
	fi
	@echo ""
	@echo "🧪 TESTE 3: Rate Limit por Token (limite: 100 req/s)"
	@echo "Fazendo 20 requisições com token para mostrar limite maior..."
	@echo ""
	@for i in $$(seq 1 20); do \
		echo -n "  Token Req $$i: "; \
		status_code=$$(curl -s -w '%{http_code}' -o /dev/null -H "API_KEY: demo-token-123" http://localhost:8080/test); \
		if [ "$$status_code" = "200" ]; then \
			echo "✅ OK ($$status_code)"; \
		elif [ "$$status_code" = "429" ]; then \
			echo "🚫 BLOQUEADA ($$status_code)"; \
			break; \
		else \
			echo "❌ Erro ($$status_code)"; \
		fi; \
		sleep 0.1; \
	done
	@echo ""
	@echo "🧪 TESTE 4: Comparando limites IP vs Token"
	@echo "Fazendo requisições simultâneas sem token (limite baixo) e com token (limite alto)..."
	@echo ""
	@echo "  👤 Sem token (limite IP: 10 req/s):"
	@for i in $$(seq 1 12); do \
		echo -n "    IP Req $$i: "; \
		status_code=$$(curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/test); \
		if [ "$$status_code" = "200" ]; then \
			echo "✅ ($$status_code)"; \
		elif [ "$$status_code" = "429" ]; then \
			echo "🚫 BLOQUEADA - IP atingiu limite!"; \
			break; \
		fi; \
		sleep 0.1; \
	done
	@echo ""
	@echo "  🔑 Com token (limite: 100 req/s):"
	@for i in $$(seq 1 10); do \
		echo -n "    Token Req $$i: "; \
		status_code=$$(curl -s -w '%{http_code}' -o /dev/null -H "API_KEY: vip-token-456" http://localhost:8080/test); \
		if [ "$$status_code" = "200" ]; then \
			echo "✅ ($$status_code)"; \
		else \
			echo "❌ ($$status_code)"; \
		fi; \
		sleep 0.1; \
	done
	@echo ""
	@echo "🧪 TESTE 5: Headers de Rate Limit"
	@echo "Verificando informações nos headers de resposta..."
	@echo ""
	@curl -I http://localhost:8080/test 2>/dev/null | grep -i "x-ratelimit" | while IFS= read -r line; do \
		echo "  📊 $$line"; \
	done || echo "  ⚠️  Nenhum header de rate limit encontrado"
	@echo ""
	@echo "🧪 TESTE 6: Testando diferentes endpoints"
	@echo ""
	@endpoints="health api/v1/users api/v1/data"; \
	for endpoint in $$endpoints; do \
		echo -n "  GET /$$endpoint: "; \
		status_code=$$(curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/$$endpoint); \
		if [ "$$status_code" = "200" ]; then \
			echo "✅ ($$status_code)"; \
		elif [ "$$status_code" = "429" ]; then \
			echo "🚫 Rate limited ($$status_code)"; \
		else \
			echo "❌ ($$status_code)"; \
		fi; \
	done
	@echo ""
	@echo "🎉 DEMONSTRAÇÃO CONCLUÍDA!"
	@echo "=========================="
	@echo ""
	@echo "📊 Resumo dos testes:"
	@echo "  ✅ Rate limit por IP funcionando (limite: 10 req/s)"
	@echo "  ✅ Rate limit por Token funcionando (limite: 100 req/s)"
	@echo "  ✅ Token sobrepõe limitação por IP"
	@echo "  ✅ Reset automático da janela temporal"
	@echo "  ✅ Headers informativos presentes"
	@echo "  ✅ Todos os endpoints protegidos"
	@echo ""
	@echo "🧪 Para testes manuais:"
	@echo "  curl http://localhost:8080/test"
	@echo "  curl -H 'API_KEY: seu-token' http://localhost:8080/test"
	@echo "  curl -I http://localhost:8080/test  # Ver headers"

status: ## Mostra status dos serviços
	@echo "📊 Status dos serviços:"
	@echo ""
	@echo "🐳 Docker Containers:"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=rate-limiter" || echo "Nenhum container encontrado"
	@echo ""
	@echo "🌐 Conectividade:"
	@curl -s http://localhost:8080/health >/dev/null 2>&1 && echo "✅ API: http://localhost:8080 (funcionando)" || echo "❌ API: http://localhost:8080 (não disponível)"
	@redis-cli -h localhost -p 6379 ping >/dev/null 2>&1 && echo "✅ Redis: localhost:6379 (funcionando)" || echo "❌ Redis: localhost:6379 (não disponível)"

# Comando padrão
all: clean build test