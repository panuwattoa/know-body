DB_URL ?= postgres://knowbody:knowbody@localhost:5432/knowbody?sslmode=disable

.PHONY: run build test vet db-up db-down migrate psql tidy

run: ## run the API (loads .env if present)
	@[ -f .env ] && export $$(grep -v '^#' .env | xargs) ; go run ./cmd/server

build:
	go build -o bin/server ./cmd/server

test:
	go test ./...

vet:
	go vet ./...

db-up: ## start local Postgres
	docker compose up -d db
	@echo "waiting for postgres..." ; sleep 3

db-down:
	docker compose down

migrate: ## apply all SQL migrations in order
	@for f in migrations/*.sql ; do echo "→ $$f" ; psql "$(DB_URL)" -v ON_ERROR_STOP=1 -f $$f ; done

psql:
	psql "$(DB_URL)"

tidy:
	go mod tidy
