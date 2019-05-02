XjzProxy
=========

## Names

* `resolver`: Process a request, such as SSL, CONNECT(tunnel), HTTP1 and HTTP2.
* `proxy_client`: Send request to real remote server


## TODOs

### V1 

- [ ] ------ 1 ------ (7.0 - 5.0)
- [o] 3.0 GRPC on http2
- [o] 2.0 document renderer api project
- [ ] 2.0 diff request params & response data, and generate report
- [ ] ------ 2 ------ (15)
- [o] 15  GUI: GTK3 
- [ ] ------ 3 ------ (11)
- [ ] 2.0 diff request params & response data, and generate report
- [o] 5.0 build portable ruby
- [ ] 2.0 link history & api, diff, export, etc in history page
- [ ] 2.0 apdate request/response before process
- [ ] 2.0 make better forward_streams. Fiber(better)/Thread 
- [ ] 2.0 For QA, easy to change data
- [o] 2.0 protect code
- [ ] ------ 4 ------ (3.5)
- [ ] 3.0 generate apidoc from real request
- [ ] 0.5 script types

### V2

16.5d => 18d

**Proxy**


- Port
- CA
- Project in a dir & watch dir

2d

**History**

- Filter 1d
- Copy Req as cURL 0.5d
- Diff params and headers of request, and response body 1d

2.5d


**Doc/Project**

- Doc style 2d
- Export as PDF, HTML 1d
- Online / Offline 1d

4d

**Report**

- Slowest 10 Req(online) 0.5d
- Most reqs in n seconds 0.5d
- All error requests(404) and not match doc 2d

3d


**Other**

- Response disk cache 2d
- Chinese doc 1d
- Test version & software sign 2d

5d



## TODO Libraries

15
* https://github.com/filewatcher/filewatcher
