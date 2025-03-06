FROM yg397/openresty-thrift:xenial

RUN git clone https://github.com/delimitrou/DeathStarBench.git /tmp/DeathStarBench &&  \
    cd /tmp/DeathStarBench &&  \
    git checkout b2b7af9 && \
    cp -r /tmp/DeathStarBench/socialNetwork/nginx-web-server /usr/local/openresty/nginx && \
    cp -r /tmp/DeathStarBench/socialNetwork/gen-lua /gen-lua && \
    cp -r /tmp/DeathStarBench/socialNetwork/docker/openresty-thrift/lua-thrift /usr/local/openresty/lualib/thrift
