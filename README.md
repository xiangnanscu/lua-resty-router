# lua-resty-router

high performance router

# Router

## create

```lua
---@alias Route {[1]:string, [2]:function|string, [3]?:string|string[]}
(method) Router:create(routes: Route[])
  -> Router
```

init a router with routes

## insert

```lua
(method) Router:insert(path: string, handler: string|function, methods?: string|string[])
  -> Router
```

insert a route

## match

```lua
(method) Router:match(path: string, method: string)
  -> string|function
  2. { [string]: string|number }?
```

match a http request

# Synopsis

```lua
local Router = require('resty.router')
local tree = Router:create {
  { '/',                      'root',    { 'GET', 'patch' } },
  { '/v1',                    'v1',      'GET' },
  { '/v1/#age',               'age',     'GET' },
  { '/v1/:name',              'name',    'GET' },
  { '/v1/<version>\\d+-\\d+', 'version', 'GET' },
  { '/v1/handler',            'v1h',     'GET' },
  { '/name',                  'name',    'GET' },
  { '/name/:name/age/#age',   'person',  'GET' },
  { '/v2',                    'v2',      'post' },
  { '/name/:name/path/*path', 'path',    'get' },
}

local res, err, status = tree:match('/', 'POST')
assert(res == nil and err == 'method not allowed' and status == 405)
local res, params, status = tree:match('/v2/foo', 'GET')
assert(res == nil and params == 'page not found' and status == 404)
assert(tree:match('/', 'GET') == tree:match('/', 'PATCH'))
assert(tree:match('/v1', 'GET') == 'v1')
local res, params = tree:match('/v1/#age', 'GET')
assert(res == 'age')
assert(params == nil)
local res, params = tree:match('/v1/23', 'GET')
assert(res == 'age')
assert(params.age == 23)
local res, params = tree:match('/v1/1-3', 'GET')
assert(res == 'version')
assert(params.version == '1-3')
local res, params = tree:match('/v1/kate', 'GET')
assert(res == 'name')
assert(params.name == 'kate')
local res, params = tree:match('/name/kate/age/23', 'GET')
assert(res == 'person')
assert(params.name == 'kate')
assert(params.age == 23)
assert(tree:match('/name', 'GET') == 'name')
local res, params = tree:match('/name/repo/path/lib/bar/foo.js', 'GET')
assert(res == 'path')
assert(params.name == 'repo')
assert(params.path == '/lib/bar/foo.js')
```

Or like this:

```lua
local tree = Router:new()
tree:insert('/v1', 'v1')
tree:post('/v2', 'v2')
assert(tree:match('/v1','GET') == 'v1')
assert(tree:match('/v2','POST') == 'v2')
assert(tree:match('/v2','GET') == nil)
```
