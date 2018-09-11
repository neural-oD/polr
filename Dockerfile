FROM php:7.2-fpm-alpine

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /tmp
ENV COMPOSER_VERSION 1.7.2

# docker-entrypoint.sh dependencies
RUN echo "memory_limit=-1" > "$PHP_INI_DIR/conf.d/memory-limit.ini" \
 && echo "date.timezone=${PHP_TIMEZONE:-UTC}" > "$PHP_INI_DIR/conf.d/date_timezone.ini" \
 && apk add --no-cache --virtual .build-deps libjpeg-turbo-dev libpng-dev \
 && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
 && docker-php-ext-install gd mysqli opcache tokenizer json zip pdo_mysql \
 &&	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --virtual .polr-phpexts-rundeps $runDeps \
  && apk add --no-cache bash sed git subversion openssh mercurial tini patch \
  && curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/b107d959a5924af895807021fcef4ffec5a76aa9/web/installer \
   && php -r " \
      \$signature = '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061'; \
      \$hash = hash('SHA384', file_get_contents('/tmp/installer.php')); \
      if (!hash_equals(\$signature, \$hash)) { \
          unlink('/tmp/installer.php'); \
          echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
          exit(1); \
      }"; \
   php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION} \
   && composer --ansi --version --no-interaction \
   && rm -rf /tmp/* /tmp/.htaccess \
   && cd /usr/src \
   && curl -L https://github.com/cydrobolt/polr/archive/2.2.0.tar.gz > polr.tar.gz \
   && tar xfvz polr.tar.gz && mv polr-2.2.0 polr  \
   && chown -R www-data:www-data /usr/src/polr && cd polr \
   && php /usr/bin/composer install --no-dev -o


VOLUME /var/www/html

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/usr/local/sbin/php-fpm"]
