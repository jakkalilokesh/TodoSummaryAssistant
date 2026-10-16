# Build stage
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# Runtime stage
FROM nginxinc/nginx-unprivileged:stable-alpine

COPY --from=build /app/build/ /usr/share/nginx/html/

EXPOSE 8080

USER 101

CMD ["nginx", "-g", "daemon off;"]
