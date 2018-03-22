# lua-resty-router
simple case sensitive router

# Requirements
Nothing.

# Synopsis
define a router as a module. say `test/init.lua` 

```lua
local Router = require "resty.router"

local router = Router:new()

local function foo(req) 
    ngx.print('in foo method is: '..req.get_method()) 
end
router "/foo" (foo)

local function number(req) 
    ngx.print('number in url: '..req.kwargs[1]) 
end
router:add{ [[~^/(\d+)$]], number}

local function word(req) 
    ngx.print('word in url: '..req.kwargs.word) 
end
router:add{ '~^/(?<word>\\w+)$', word}

router "/bar" {
    get = function (req) 
        ngx.print('in bar http version is: '..req.http_version())
    end,
}

return router
```
and then use it like this:
```
server {
    listen 8000;

    location / {
        content_by_lua_block {
            local res, err, status = require"test/init":exec()
            if err then
                ngx.status = status 
                ngx.say(err)
            end
        }
    }
}
```