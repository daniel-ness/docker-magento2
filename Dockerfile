FROM magento/magento-cloud-docker-php:7.2-fpm-1.0

ENV MYSQL_MAJOR 5.7
ENV MAGENTO_VERSION 2.3.2-p2
ENV MAGENTO_TARBALL 2.3.2-p2.tar.gz
ENV PHP_MEMORY_LIMIT -1

RUN echo "deb http://repo.mysql.com/apt/debian/ stretch mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list \
    && { \
                echo mysql-community-server mysql-community-server/data-dir select ''; \
                echo mysql-community-server mysql-community-server/root-pass password ''; \
                echo mysql-community-server mysql-community-server/re-root-pass password ''; \
                echo mysql-community-server mysql-community-server/remove-test-db select false; \
        } | debconf-set-selections \
    && apt-get update \
    && apt-get install -y --allow-unauthenticated mysql-server

RUN wget -q "https://github.com/magento/magento2/archive/${MAGENTO_TARBALL}" -O "/tmp/magento.tar.gz"
RUN wget -q "https://github.com/magento/magento2-sample-data/archive/${MAGENTO_TARBALL}" -O "/tmp/magento-sample.tar.gz"

RUN curl -sS https://getcomposer.org/installer | php -dmemory_limit=-1 -- --install-dir=/usr/local/bin --filename=composer

COPY ./install-magento.sh /install-magento.sh
RUN chmod +x /install-magento.sh
RUN /bin/bash /install-magento.sh

WORKDIR /var/www/magento2
