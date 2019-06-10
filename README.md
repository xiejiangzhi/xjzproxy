XjzProxy
=========

## Names

* `resolver`: Process a request, such as SSL, CONNECT(tunnel), HTTP1 and HTTP2.
* `proxy_client`: Send request to real remote server


## TODOs

### V1 

- [o] ------ 1 ------ (7.0 - 5.0)
- [o] 3.0 GRPC on http2
- [o] 2.0 document renderer api project
- [o] 2.0 diff request params & response data, and generate report
- [o] ------ 2 ------ (15)
- [o] 15  GUI: GTK3 
- [ ] ------ 3 ------ (11)
- [o] 2.0 diff request params & response data, and generate report
- [o] 5.0 build portable ruby
- [-] 2.0 link history & api, diff, export, etc in history page
- [ ] 2.0 update request/response before process
- [-] 2.0 make better forward_streams. Fiber(better)/Thread 
- [ ] 2.0 For QA, easy to change data
- [o] 2.0 protect code
- [ ] ------ 4 ------ (3.5)
- [ ] 3.0 generate apidoc from real request
- [ ] 0.5 script types
- [ ] 1.0 Resend Request
- [-] 1.0 Export as PDF, HTML
- [ ] 根据文档自动生成测试代码，写测试代码时，直接调用接口来检查数据。expect(JSON.parse(response.body)).to match_doc(:r_list_users)

### V2

17d => 18d

**Proxy Done**


- Port
- CA
- Project in a dir & watch dir

2d

**History**

- Filter 1d
- Copy Req as cURL 0.5d
- Diff params and headers of request, and response body 1d
- Diff tag on request tab(need check api always) 0.5d
- Diff GRPC(send schame when parse request.body, response.body) 0.5d

3.0d


**Project/doc**

- Doc style 2d
- Online / Offline 1d

3d

**Report**

- All error requests(404) and not match doc 2d
- How many errors and show 5xx 4xx count

3d


**Other**

- Save proxy config
- Test version & software sign 2d
- 放入暗桩（正常版本不会运行的或是在激活后一定时间再进行检查），可以通过 ERB 来生成代码 1d
- Chinese doc 1d
- Auto test all APIs, each apis and send request, see result in history and report 2d

7d


**todo**




### V3

- [x] Document
- [x] response 切换 
- [x] IO forward
- [x] check license online, allow most two people online


### V4

- [ ] Generate string from regexp


## License verify server

uri: `l.xjz.pw/v`

params:

* l: license text
* id: user computer id

response:

```
{
  valid: true, // false will remove the license
}
```



## TODO

- Allow disable mock, but check server response based on the document

