FROM node:20-alpine
WORKDIR /app
COPY server.js tasklist.html ./
EXPOSE 8080
ENV PORT=8080
ENV DATA_DIR=/data
CMD ["node", "server.js"]
