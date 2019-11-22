#!/bin/bash

cd / \
  && tar xzf /tmp/magento2.tar.gz \
  && service mysql start \
  && service nginx start \
  && php-fpm -F
