# lua_nsc
dynamic upstream control on nginx

## how to use

1. install nginx with lua support

my nginx config argument are as follow:
configure arguments: --user=web --group=web --prefix=/data/server/nginx --with-http_realip_module --with-http_stub_status_module --with-http_sysguard_module --with-syslog --with-http_ssl_module --with-http_v2_module --with-http_dyups_module --add-module=../ngx_cache_purge-2.1 --with-google_perftools_module --add-module=../ngx_devel_kit-0.2.19 --add-module=../lua-nginx-module-0.10.6 --add-module=../lua-upstream-nginx-module-master --with-ld-opt='-ldl -ltcmalloc'

2. config nginx

```sh
cp demos/nginx.conf /path/to/nginx/conf/nginx.conf
cp -r demos/upstream /path/to/nginx/conf/upstream
cp -r demos/vhosts /path/to/nginx/conf/vhosts
```

3. add your service into zookeeper

the zookeeper path prefix was configed in nsc_config.lua  zk_path_tpl

nsc_config.lua config example:

```lua
local NSC_CONFIG = {
    -- name service config
    name_service = {
        zk_path_tpl = "/arch_group/test/%s",
        lrucache_timeout = 60,  -- 60s
        lrucache_size = 200,  -- lrucache size
    },
}

return NSC_CONFIG
```

zookeeper config example:

node1 path is "/arch_group/test/test_namespace/192.168.56.101_10001"; node1 value is {"weight": 3}
node2 path is "/arch_group/test/test_namespace/192.168.56.101_10002"; node2 value is {"weight": 2}
node3 path is "/arch_group/test/test_namespace/192.168.56.101_10003"; node3 value is {"weight": 1}


4. upstream config example

```
upstream nsc.test_namespace {
    server    192.168.56.101:8888   max_fails=2 fail_timeout=2s weight=1; # only for nginx -t check
    balancer_by_lua_block  {
        -- strategy can add backup strategy like nginx backup servers
        local strategy = {
            host = "192.168.56.101",  -- will use this host as default
            backup = {
                "192.168.56.101",
            },
        }
        nsc.balance("test_namespace", strategy)
    }
    keepalive 64;
}
```

5. vhosts config example

```
server {
    listen 6677;
    server_name  192.168.56.101;

    access_log /data/logs/nginx.log  main;

    location / {
        default_type 'text/plain';
        proxy_buffering    off;
        proxy_set_header            Host $host;
        proxy_set_header            X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_redirect              off;
        proxy_connect_timeout       10;
        proxy_send_timeout          30;
        proxy_read_timeout          30;
        proxy_pass                  http://nsc.test_namespace;
    }
    location = /debug/upstream/servers {
        default_type 'text/json';
        content_by_lua_block {
            -- strategy can add backup strategy like nginx backup servers
            local strategy = {
               host = "192.168.56.101",
               backup = {
                   "192.168.56.101",
               },
            }
            nsc.get_servers("test_namespace", strategy)
        }
    }
}
```


## how to test

1. send request to nginx vhosts

curl http://localhost:6677/

2. get what servers were configed in dynamic upstream

curl http://localhost:6677/debug/upstream/servers
