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

test-manual: ## Executa testes manuais (requer servidor rodando)
	@echo "🔍 Executando testes manuais..."
	@echo "⚠️  Certifique-se que o servidor está rodando em localhost:8080"
	./test_manual.sh

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
	@command -v jq >/dev/null 2>&1 || { echo "⚠️  jq não encontrado. Instale jq para melhor visualização dos testes"; }
	@echo "✅ Verificação de dependências concluída!"

dev: ## Inicia ambiente de desenvolvimento completo e executa demo
	@echo "🚀 RATE LIMITER - DEMO COMPLETA"
	@echo "================================"
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
	@echo "5️⃣ Demonstração rápida:"
	@echo ""
	@echo "  📋 Testando rate limit por IP..."
	@echo "  Request 1: $$(curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/test)"
	@echo "  Request 2: $$(curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/test)"
	@echo "  Request 3: $$(curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/test)"
	@echo ""
	@echo "  📋 Testando com token..."
	@echo "  Token Request 1: $$(curl -s -w '%{http_code}' -o /dev/null -H 'API_KEY: demo' http://localhost:8080/test)"
	@echo "  Token Request 2: $$(curl -s -w '%{http_code}' -o /dev/null -H 'API_KEY: demo' http://localhost:8080/test)"
	@echo ""
	@echo "🎉 DEMO CONCLUÍDA!"
	@echo "=================="
	@echo "📊 Serviços rodando:"
	@echo "  • API: http://localhost:8080"
	@echo "  • Redis: localhost:6379"
	@echo ""
	@echo "🧪 Testes manuais:"
	@echo "  curl http://localhost:8080/test"
	@echo "  curl -H 'API_KEY: token123' http://localhost:8080/test"
	@echo ""
	@echo "🔧 Comandos úteis:"
	@echo "  • make docker-logs  (ver logs)"
	@echo "  • make docker-down  (parar tudo)"

demo: docker-up ## Demonstração completa (modo legado)
	@echo "🎯 Iniciando demonstração..."
	@echo "⏳ Aguardando serviços iniciarem..."
	@sleep 5
	@echo "🧪 Executando testes de demonstração..."
	@$(MAKE) test-manual || true
	@echo "🎉 Demonstração concluída!"

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