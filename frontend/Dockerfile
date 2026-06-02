FROM node:20-alpine

WORKDIR /app

# Instala dependências primeiro (camada cacheável). Usa o lockfile versionado.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

EXPOSE 5173

# --host 0.0.0.0 expõe o dev server para fora do container.
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
