FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY . .

# Create dirs for certs and pass model (mounted as volumes)
RUN mkdir -p /app/certs /app/pass-model

EXPOSE 3939

CMD ["node", "index.js"]
