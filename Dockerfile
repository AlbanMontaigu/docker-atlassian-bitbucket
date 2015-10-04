# -------------------------------------------------------------------------------------------------------------------------
#
# ATLASSIAN STASH STANDALONE SERVER
#
# Thanks to original project example : https://registry.hub.docker.com/u/cptactionhank/atlassian-stash/dockerfile/
#
# @see https://registry.hub.docker.com/u/atlassian/stash/dockerfile/
# @see https://confluence.atlassian.com/display/STASH/Install+Stash+from+an+archive+file
# @see https://confluence.atlassian.com/display/STASH/Connecting+Stash+to+an+external+database
# @see https://confluence.atlassian.com/display/STASH/Connecting+Stash+to+PostgreSQL
# @see https://jdbc.postgresql.org/download.html
# @see https://confluence.atlassian.com/display/STASH/Supported+platforms
# @see http://www.cyberciti.biz/faq/linux-unix-extracting-specific-files/
#
# -------------------------------------------------------------------------------------------------------------------------


# Base image
FROM java:8


# Maintainer
MAINTAINER alban.montaigu@gmail.com


# Configuration variables.
ENV STASH_HOME="/var/local/atlassian/stash" \
    STASH_INSTALL="/usr/local/atlassian/stash" \
    STASH_VERSION="3.11.2"


# Base system update (isolated to not reproduce each time)
RUN set -x \
    && apt-get update --quiet \
    && apt-get install --quiet --yes --no-install-recommends libtcnative-1 git-core xmlstarlet \
    && apt-get clean


# Bonus tools
RUN set -x \
    &&curl -o /usr/local/bin/gosu -sL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$(dpkg --print-architecture)" \
    && chmod +x /usr/local/bin/gosu


# Install Atlassian stash and helper tools and setup initial home
# directory structure (isolated to not reproduce each time).
RUN set -x \
    && mkdir -p                "${STASH_HOME}" \
    && chmod -R 700            "${STASH_HOME}" \
    && chown -R daemon:daemon  "${STASH_HOME}" \
    && mkdir -p                "${STASH_INSTALL}/conf/Catalina" \
    && curl -Ls                "https://downloads.atlassian.com/software/stash/downloads/atlassian-stash-${STASH_VERSION}.tar.gz" | tar -xz --directory "${STASH_INSTALL}" --strip-components=1 --no-same-owner \
    && chmod -R 700            "${STASH_INSTALL}/conf" \
    && chmod -R 700            "${STASH_INSTALL}/logs" \
    && chmod -R 700            "${STASH_INSTALL}/temp" \
    && chmod -R 700            "${STASH_INSTALL}/work" \
    && chown -R daemon:daemon  "${STASH_INSTALL}/conf" \
    && chown -R daemon:daemon  "${STASH_INSTALL}/logs" \
    && chown -R daemon:daemon  "${STASH_INSTALL}/temp" \
    && chown -R daemon:daemon  "${STASH_INSTALL}/work"


# Custom stash configuration (isolated to not reproduce each time)
RUN set -x \
    && ln --symbolic          "/usr/lib/x86_64-linux-gnu/libtcnative-1.so" "${STASH_INSTALL}/lib/native/libtcnative-1.so" \
    && sed --in-place         's/^# umask 0027$/umask 0027/g' "${STASH_INSTALL}/bin/setenv.sh" \
    && xmlstarlet             ed --inplace \
        --delete              "Server/Service/Engine/Host/@xmlValidation" \
        --delete              "Server/Service/Engine/Host/@xmlNamespaceAware" \
        --update               "Server/Service/Engine/Host/Context/@path" --value "/stash" \
                              "${STASH_INSTALL}/conf/server.xml"


# PostgreSQL connector for stash (isolated to not reproduce each time)
RUN set -x \
    && curl -Ls -o ${STASH_INSTALL}/lib/postgresql-9.4-1201.jdbc41.jar https://jdbc.postgresql.org/download/postgresql-9.4-1201.jdbc41.jar


# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER daemon:daemon


# Expose default HTTP connector port + SSH Port
EXPOSE 7990 7999


# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/local/atlassian/stash"]


# Set the default working directory as the installation directory.
WORKDIR ${STASH_INSTALL}


# Run Atlassian stash as a foreground process by default.
CMD ["./bin/start-stash.sh", "-fg"]
