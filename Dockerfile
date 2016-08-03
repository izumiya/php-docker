FROM php:alpine

ENV DOCKER_BUCKET get.docker.com
ENV DOCKER_VERSION 1.11.2
ENV DOCKER_SHA256 8c2e0c35e3cda11706f54b2d46c2521a6e9026a7b13c7d4b8ae1f3a706fc55e1

RUN set -x \
    && curl -fSL "https://${DOCKER_BUCKET}/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz" -o docker.tgz \
    && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
    && tar -xzvf docker.tgz \
    && mv docker/* /usr/local/bin/ \
    && rmdir docker \
    && rm docker.tgz \
    && docker -v

RUN apk add --no-cache \
        git \
        openssh-client \
        python \
        py-pip \
        zip \
        bash \
    && pip install docker-compose \
    && pip install awscli --ignore-installed six

RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/local/bin --filename=composer --version=1.2.0