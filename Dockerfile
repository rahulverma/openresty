FROM alpine:3.4

ENV OPENRESTY_VERSION 1.9.7.5
ENV OPENRESTY_PREFIX /opt/openresty
ENV NGINX_PREFIX /opt/openresty/nginx
ENV VAR_PREFIX /var/nginx

ENV LUAROCKS_VERSION 2.3.0

# NginX prefix is automatically set by OpenResty to $OPENRESTY_PREFIX/nginx
# look for $ngx_prefix in https://github.com/openresty/ngx_openresty/blob/master/util/configure

# Install Dependencies
RUN apk update \
 && apk add --virtual build-deps \
    make gcc musl-dev \
    pcre-dev openssl-dev zlib-dev ncurses-dev readline-dev \
    curl perl

# Install Openresty
RUN mkdir -p /root/ngx_openresty \
 && cd /root/ngx_openresty \
 && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
 && cd openresty-* \
 && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
 && ./configure \
    --prefix=$OPENRESTY_PREFIX \
    --http-client-body-temp-path=$VAR_PREFIX/client_body_temp \
    --http-proxy-temp-path=$VAR_PREFIX/proxy_temp \
    --http-log-path=$VAR_PREFIX/access.log \
    --error-log-path=$VAR_PREFIX/error.log \
    --pid-path=$VAR_PREFIX/nginx.pid \
    --lock-path=$VAR_PREFIX/nginx.lock \
    --with-luajit \
    --with-pcre-jit \
    --with-ipv6 \
    --with-http_ssl_module \
    --without-http_ssi_module \
    --without-http_userid_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    -j${NPROC} \
 && make -j${NPROC} \
 && make install \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/nginx \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/openresty \
 && ln -sf $OPENRESTY_PREFIX/bin/resty /usr/local/bin/resty \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* $OPENRESTY_PREFIX/luajit/bin/lua \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* /usr/local/bin/lua

# Install infounzip since busybox's version of unzip fails on luarock packages
RUN mkdir -p /root/unzip \
 && cd /root/unzip \
 && curl -sSL "http://downloads.sourceforge.net/infozip/unzip60.tar.gz" | tar -xvz \
 && cd unzip* \
 && cp ./unix/Makefile ./ \
 && make generic \
 && mv /usr/bin/unzip /usr/bin/unzip.old \
 && mv unzip /usr/bin/unzip

# Install Luarocks
RUN mkdir -p /root/luarocks \
 && cd /root/luarocks \
 && curl -sSL http://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz | tar -xvz \
 && cd luarocks-* \
 && ./configure \
        --prefix=/opt/openresty/luajit/ \
        --with-lua=/opt/openresty/luajit/ \
        --with-lua-bin=/opt/openresty/luajit/bin \
        --with-lua-lib=/opt/openresty/luajit/lib \
        --lua-suffix=jit-2.1.0-beta1 \
        --with-lua-include=/opt/openresty/luajit/include/luajit-2.1 \
 && make build \
 && make install

# Install lapis and moonscript
RUN /opt/openresty/luajit/bin/luarocks install lapis
RUN /opt/openresty/luajit/bin/luarocks install moonscript

# Cleanup
RUN apk del build-deps \
 && apk add libpcrecpp libpcre16 libpcre32 openssl libssl1.0 pcre libgcc libstdc++ \
 && cd /opt/openresty \
 && rm -rf /var/cache/apk/* \
 && rm -rf /root/ngx_openresty \
 && rm -rf /root/unzip \
 && rm -rf /root/luarocks \
 && rm /usr/bin/unzip \
 && mv /usr/bin/unzip.old /usr/bin/unzip

# Copy the app
COPY app /app

WORKDIR /app/

EXPOSE 8080

CMD ["nginx", "-p", "/app/", "-c", "nginx.conf"]
