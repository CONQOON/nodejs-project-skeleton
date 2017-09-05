FROM ubuntu:xenial
MAINTAINER Benjamin Gröner <bgroener@conqoon.com>

# Set the working directory to /app
WORKDIR /usr/src/app

# Add the node.js app code to the container
ADD ./code /usr/src/app


# Locale ENV stuff
ENV OS_LOCALE="de_DE.UTF-8"
RUN apt-get update && apt-get install -y locales && locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=en_US:en \
    LC_ALL=${OS_LOCALE} \
    DEBIAN_FRONTEND=noninteractive
# Nodejs ENV
ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 8.4.0
ENV YARN_VERSION 0.27.5
ENV MONGODB_MAJOR 3.4
ENV MONGODB_VERSION 3.4.7
ENV MONGODB_PACKAGE mongodb-org
ENV MONGODB_REPO repo.mongodb.org

# Create users and groups for node and mongodb
RUN \
    groupadd --gid 1000 node \
    && useradd --uid 1000 --gid node --shell /bin/bash --create-home node \
    && groupadd --gid 1001 mongodb \
    && useradd --uid 1001 --gid mongodb --shell /bin/bash --create-home mongodb

# Adding important repositories and keys
RUN \
    #Mongo DB Key
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6 \
    #Mongo DB Repository
    && echo "deb http://$MONGODB_REPO/apt/ubuntu xenial/$MONGODB_PACKAGE/$MONGODB_MAJOR multiverse" | tee /etc/apt/sources.list.d/${MONGODB_PACKAGE%-$MONGODB_MAJOR}.list


RUN \
    buildDeps='apt-utils ca-certificates jq numactl software-properties-common python-software-properties' \
    # Install common libraries
    && apt-get install --no-install-recommends -y $buildDeps \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    # Install PHP libraries
    && apt-get install -y curl


# Install nodejs
RUN \
    curl -sL https://deb.nodesource.com/setup_8.x | bash - \
    && apt-get install -y nodejs

# Install yarn
RUN set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
  done \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt/yarn \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/yarn --strip-components=1 \
  && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz


# Install mongodb
RUN \
    apt-get install -y \
        ${MONGODB_PACKAGE}=$MONGODB_VERSION \
        ${MONGODB_PACKAGE}-server=$MONGODB_VERSION \
        ${MONGODB_PACKAGE}-shell=$MONGODB_VERSION \
        ${MONGODB_PACKAGE}-mongos=$MONGODB_VERSION \
        ${MONGODB_PACKAGE}-tools=$MONGODB_VERSION \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mongodb \
    && mv /etc/mongod.conf /etc/mongod.conf.orig

RUN mkdir -p /data/db /data/configdb \
	&& chown -R mongodb:mongodb /data/db /data/configdb
VOLUME /data/db /data/configdb

# Node application port
EXPOSE 8080
# MongoDB port
EXPOSE 27017

COPY build/docker-entrypoint.sh /usr/local/bin/
RUN chmod 774 /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["start"]