# -------------------------------------------------------------------------------------------------------------------------
#
# ATLASSIAN BITBUCKET STANDALONE SERVER
#
# @see https://bitbucket.org/atlassian/docker-atlassian-bitbucket-server
# @see https://github.com/cptactionhank/docker-atlassian-bitbucket
#
# -------------------------------------------------------------------------------------------------------------------------

# Base image
FROM openjdk:8-alpine

# Maintainer
LABEL maintainer="alban.montaigu@gmail.com"

# Configuration variables.
ENV BITBUCKET_HOME="/var/atlassian/application-data/bitbucket" \
    BITBUCKET_INSTALL="/opt/atlassian/bitbucket" \
    BITBUCKET_VERSION="5.4.1"

# Base system requirement
RUN apk --no-cache add git xmlstarlet wget tomcat-native ca-certificates curl openssh \
                   bash procps openssl perl ttf-dejavu tini \

# Install Atlassian bitbucket and helper tools and setup initial home directory structure
    && mkdir -p "${BITBUCKET_HOME}" \
    && chown -R daemon:daemon "${BITBUCKET_HOME}" \
    && mkdir -p "${BITBUCKET_INSTALL}" \
    && wget -P /tmp --no-check-certificate "https://downloads.atlassian.com/software/stash/downloads/atlassian-bitbucket-${BITBUCKET_VERSION}.tar.gz" -nv \
    && tar xz -f "/tmp/atlassian-bitbucket-${BITBUCKET_VERSION}.tar.gz" --directory "${BITBUCKET_INSTALL}" --strip-components=1 --no-same-owner \
    && rm -rf "/tmp/atlassian-bitbucket-${BITBUCKET_VERSION}.tar.gz" \
    && chown -R daemon:daemon  "${BITBUCKET_INSTALL}" \

# Custom bitbucket configuration
    && ln -s "/usr/lib/libtcnative-1.so" "${BITBUCKET_INSTALL}/lib/native/libtcnative-1.so" \
    && sed --in-place 's/^# umask 0027$/umask 0027/g' "${BITBUCKET_INSTALL}/bin/setenv.sh" \
    && xmlstarlet ed --inplace \
        --delete "Server/Service/Engine/Host/@xmlValidation" \
        --delete "Server/Service/Engine/Host/@xmlNamespaceAware" \
                 "${BITBUCKET_INSTALL}/conf/server.xml" \
    && touch -d "@0" "${BITBUCKET_INSTALL}/conf/server.xml"

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER daemon:daemon

# Expose default HTTP connector port + SSH Port
EXPOSE 7990 7999

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["${BITBUCKET_HOME}"]

# Set the default working directory as the installation directory.
WORKDIR ${BITBUCKET_INSTALL}

# Run Atlassian bitbucket as a foreground process by default.
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./bin/start-bitbucket.sh", "-fg"]
