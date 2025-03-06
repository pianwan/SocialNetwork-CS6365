FROM yg397/openresty-thrift:xenial

COPY ./lua-scripts /usr/local/openresty/nginx/lua-scripts
COPY ./pages /usr/local/openresty/nginx/pages
COPY ./gen-lua /gen-lua/
COPY ./lua-thrift /usr/local/openresty/lualib/thrift/
RUN mkdir -p /usr/local/openresty/nginx/conf/
COPY ./conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
RUN mkdir -p /usr/local/openresty/nginx/
COPY ./jaeger-config.json /usr/local/openresty/nginx/jaeger-config.json