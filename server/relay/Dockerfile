FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY relay.js ./
ENV PORT=9080
EXPOSE 9080
CMD ["node", "relay.js"]
