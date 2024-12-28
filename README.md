# lua-resty-router

Elegant, performant and productive router for Openresty.

# Quick Start

It's recommended to use npm to scaffold a lua-resty-router project.

```bash
npm create resty@latest -y
```
Then follow the instructions to complete the project.

# Dependencies

* [OpenResty](https://openresty.org/)
* (Optional) [lfs](https://luarocks.org/modules/hisham/luafilesystem) or [syscall.lfs](https://github.com/justincormack/ljsyscall) - if you want to use `fs` method to load routes from directory

# Synopsis

```lua
local Router = require('resty.router')

local router = Router:new()

local cnt = 0
local error_cnt = 0

-- Test events
-- for test purpose, assume the nginx is single-threaded
router:on('add', function(ctx)
  cnt = cnt + 1
end)

router:on('error', function(ctx)
  error_cnt = error_cnt + 1
end)

-- Test plugins
router:use(function(ctx)
  ctx.cnt = cnt
  ctx.error_cnt = error_cnt
end)

-- 1. Test static path
router:get("/hello", function()
  return "Hello World"
end)

-- Test custom success status code
router:get("/hello-201", function()
  return "Hello World", 201
end)

-- 2. Test JSON response
router:get("/json", function()
  return { message = "success", code = 0 }
end)

-- 3. Test dynamic path parameters
router:get("/users/#id", function(ctx)
  return {
    id = ctx.params.id,
    type = type(ctx.params.id)
  }
end)

router:get("/users/:name", function(ctx)
  return {
    name = ctx.params.name,
    type = type(ctx.params.name)
  }
end)

-- 4. Test regex path
router:get([[/version/<ver>\d+\.\d+]], function(ctx)
  return {
    version = ctx.params.ver
  }
end)

-- 5. Test wildcard
router:get("/files/*path", function(ctx)
  return ctx.params.path
end)

-- 6. Test other HTTP methods
router:post("/accounts", function(ctx)
  return { method = "POST" }
end)

router:put("/accounts/#id", function(ctx)
  return { method = "PUT", id = ctx.params.id }
end)

-- 7. Test error handling
router:get("/error", function()
  error("Test Error")
end)

-- Test custom error thrown by error()
router:get("/custom-error", function()
  error({ code = 400, message = "Custom Error" })
end)

-- Test error in the form of return nil, err, code
router:get("/return-error", function()
  return nil, "Parameter Error", 402
end)

-- Test handled error
router:get("/handled-error", function()
  error { "handled error" }
end)

-- 8. Test status code
router:get("/404", function()
  return nil, "Not Found", 404
end)

-- 9. Test HTML response
router:get("/html", function()
  return "<h1>Hello HTML</h1>"
end)
-- Test HTML error
router:get("/html-error", function()
  return nil, "<h1>Hello HTML error</h1>", 501
end)
-- Test HTML error thrown by error()
router:get("/html-error2", function()
  error { "<h1>Hello HTML error2</h1>" }
end)

-- 10. Test function return
router:get("/func", function(ctx)
  return function()
    ngx.header.content_type = 'text/plain; charset=utf-8'
    ngx.say("function called")
  end
end)

-- 11. Check if events are executing properly
router:get("/add", function(ctx)
  router:emit('add')
  return ctx.cnt
end)

router:get("/events", function(ctx)
  return ctx.cnt
end)

return router

```

# Api

## new

```lua
(method) Router:new()
  -> Router
```

create a router.

## insert

```lua
(method) Router:insert(path: string, handler: string|function, methods?: string|string[])
  -> Router
```

insert a route.

## extend

```lua
---@alias Route {[1]:string, [2]:function|string, [3]?:string|string[]}
(method) Router:extend(routes: Route[])
  -> Router
```

insert routes to a router.

## match

```lua
(method) Router:match(path: string, method: string)
  ->
  1. string|function
  2. { [string]: string|number }?
```

match a http request

## run
```lua
(method) Router:run()
  -> nil
```
dispatch http request

## fs

```lua
(method) Router:fs(dir: string)
  -> nil
```

load routes from directory (requires `lfs` or `syscall.lfs` module).

# reference

- [nginx api for lua](https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#nginx-api-for-lua)