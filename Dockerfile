FROM php:alpine

#### ruby:2.3-alpine ####

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
    && { \
        echo 'install: --no-document'; \
        echo 'update: --no-document'; \
    } >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.3
ENV RUBY_VERSION 2.3.1
ENV RUBY_DOWNLOAD_SHA256 b87c738cb2032bf4920fef8e3864dc5cf8eae9d89d8d523ce0236945c5797dcd
ENV RUBYGEMS_VERSION 2.6.6

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN set -ex \
    && apk add --no-cache --virtual .ruby-builddeps \
        autoconf \
        bison \
        bzip2 \
        bzip2-dev \
        ca-certificates \
        coreutils \
        curl \
        gcc \
        gdbm-dev \
        glib-dev \
        libc-dev \
        libffi-dev \
        libxml2-dev \
        libxslt-dev \
        linux-headers \
        make \
        ncurses-dev \
        openssl-dev \
        procps \
# https://bugs.ruby-lang.org/issues/11869 and https://github.com/docker-library/ruby/issues/75
        readline-dev \
        ruby \
        yaml-dev \
        zlib-dev \
    && curl -fSL -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
    && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src \
    && tar -xzf ruby.tar.gz -C /usr/src \
    && mv "/usr/src/ruby-$RUBY_VERSION" /usr/src/ruby \
    && rm ruby.tar.gz \
    && cd /usr/src/ruby \
    && { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c \
    && autoconf \
    # the configure script does not detect isnan/isinf as macros
    && ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
        ./configure --disable-install-doc \
    && make -j"$(getconf _NPROCESSORS_ONLN)" \
    && make install \
    && runDeps="$( \
        scanelf --needed --nobanner --recursive /usr/local \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --virtual .ruby-rundeps $runDeps \
        bzip2 \
        ca-certificates \
        curl \
        libffi-dev \
        openssl-dev \
        yaml-dev \
        procps \
        zlib-dev \
    && apk del .ruby-builddeps \
    && gem update --system $RUBYGEMS_VERSION \
    && rm -r /usr/src/ruby

ENV BUNDLER_VERSION 1.12.5

RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_BIN="$GEM_HOME/bin" \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
    && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

#### docker:1.11 + rwhub/ci_docker ####

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

#### php composer ####

ENV PHP_COMPOSER_VERSION 1.2.0

RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/local/bin --filename=composer --version=$PHP_COMPOSER_VERSION

#### xdebug ####

RUN set -ex \
    && apk add --no-cache --virtual .xdebug-builddeps \
        autoconf \
        gcc \
        libc-dev \
        make \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .xdebug-builddeps

#### dpl ####

ENV DPL_VERSION 1.8.17
ENV NOKOGIRI_VERSION 1.6.8
ENV AWS_SDK_VERSION 1.66.0
ENV RUBY_ZIP_VERSION 1.2.0

RUN set -ex \
    && apk add --no-cache --virtual .dpl-builddeps \
        autoconf \
        gcc \
        libc-dev \
        libxml2-dev \
        make \
    && gem install nokogiri -v $NOKOGIRI_VERSION \
    && gem install dpl -v $DPL_VERSION \
    && gem install aws-sdk-v1 -v $AWS_SDK_VERSION \
    && gem install rubyzip -v $RUBY_ZIP_VERSION \
    && apk del .dpl-builddeps

#### mysql ####

RUN docker-php-ext-install pdo_mysql
