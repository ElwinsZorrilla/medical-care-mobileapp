# Levanta el front web contra el backend para pruebas end-to-end.
# El backend vive en su propio repo; acá solo se consume.
#
#   docker compose up --build
#   → front  http://localhost:8080
#   → api    http://localhost:3000/docs   (Swagger, RNF-15)

name: medicare

services:
  front-web:
    build:
      context: ..
      dockerfile: docker/Dockerfile
      target: web
      args:
        API_BASE_URL: http://localhost:3000
        SOCKET_URL: ws://localhost:3000
    ports: ["8080:8080"]
    depends_on:
      api: { condition: service_healthy }
    restart: unless-stopped

  api:
    # Ajustar al repo real del back. Si el back no tiene Dockerfile,
    # levantarlo aparte y dejar solo db/cache acá.
    build:
      context: ../../medical-care-back
      dockerfile: Dockerfile
    environment:
      NODE_ENV: development
      DATABASE_URL: postgres://medicare:medicare@db:5432/medicare
      REDIS_URL: redis://cache:6379
      TZ: UTC                      # RNF-18: el servidor vive en UTC
    ports: ["3000:3000"]
    depends_on:
      db:    { condition: service_healthy }
      cache: { condition: service_healthy }
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 10s
      timeout: 3s
      retries: 10
      start_period: 20s

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: medicare
      POSTGRES_PASSWORD: medicare
      POSTGRES_DB: medicare
      TZ: UTC
    volumes: ["pgdata:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U medicare"]
      interval: 5s
      timeout: 3s
      retries: 10

  cache:
    image: redis:7-alpine
    command: ["redis-server", "--save", "60", "1"]
    volumes: ["redisdata:/data"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  pgdata:
  redisdata:
