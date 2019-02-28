XjzProxy
=========

## Names

* `user`: Browser or other client, a connection of proxy port
* `muddy_client`: a connection to connect resolver service
* `resolver`: a server to parse SSL or HTTPS
* `clear_user`: a connection of muddy_client
* `h2_user`: a connection of clear HTTP2
* `h2_resolver`: get a clear_user
* `remote`: a connection that connect to final data server

---

HTTP user cannot direct to remote
HTTPS user will connect to SSL resolver, then get a clear user
HTTP2 user will connnect to SSL resolver, then get a h2 user. And h2 user connect to a h2 resolver, then get a clear user

