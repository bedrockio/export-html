# THIS DOCKER FILES SOLVES THE ISSUE OF puppeteer.launch() BEING STUCK WITHOUT ANY ERROR MESSAGE ON MAC
# SOLUTION FROM https://github.com/puppeteer/puppeteer/issues/7746#issuecomment-1337583474

FROM node:16.18-bullseye-slim AS development

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
RUN apt-get update \
    && apt-get install -y chromium \
    fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 \
    --no-install-recommends

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

COPY package.json /service/package.json
COPY yarn.lock /service/yarn.lock

RUN cd /service; yarn install;

COPY . ./service
WORKDIR /service

RUN npm install

CMD ["npm", "start"]