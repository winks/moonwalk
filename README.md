# moonwalk

This is moonwalk, an alternative implementation of [pants](https://github.com/hmans/pants).

I'd be surprised if you'd get this to run.

## Requirements

  * openresty, 1.7.0.1 or maybe older
  * postgres 9.1+134wheezy4 or another version
  * luarocks compiled for luajit
    * lunamark 0.3-2
    * lua-cjson? 2.1.0-1

## Additional info

  * Uses the same db scheme as pants, for the most part


## nginx.conf - the relevant parts

```

http {

# [...]

    lua_package_path "/path/to/moonwalk/?.lua;;";

    upstream database {
        postgres_server 127.0.0.1 dbname=DBNAME user=DBUSER password=DBPASS;
    }

    server {

# [...]

        set $root /path/to/moonwalk/;
        root $root/public/;

        location /db/query {
           internal;
           postgres_pass database;
           postgres_query $echo_request_body;
        }

        location / {
          try_files $uri @lua;
        }
        location @lua {
          content_by_lua_file $root/index.lua;
        }
    }
}
```
