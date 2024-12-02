local Router = require('./lib/resty/router')
local router = Router:create {
  { '/',                      'root',    { 'GET', 'patch' } },
  { '/v1',                    'v1',      'GET' },
  { '/v1/#age',               'age',     'GET' },
  { '/v1/:name',              'name',    'GET' },
  { '/v1/<version>\\d+-\\d+', 'version', 'GET' },
  { '/v1/handler',            'v1h',     'GET' },
  { '/name',                  'name',    'GET' },
  { '/name/:name/age/#age',   'person',  'GET' },
  { '/v2',                    'v2',      'post' },
  { '/repo/:repo/path/*path', 'rest',    'get' },
}

local res, status = router:match('/', 'POST')
assert(res == nil and status == 405)
local res, status = router:match('/v2/foo', 'GET')
assert(res == nil and status == 404)
assert(router:match('/', 'GET') == router:match('/', 'PATCH'))
assert(router:match('/v1', 'GET') == 'v1')
local res, params = router:match('/v1/#age', 'GET')
assert(res == 'age')
assert(params == nil)
local res, params = router:match('/v1/23', 'GET')
assert(res == 'age')
assert(params.age == 23)
local res, params = router:match('/v1/1-3', 'GET')
assert(res == 'version')
assert(params.version == '1-3')
local res, params = router:match('/v1/kate', 'GET')
assert(res == 'name')
assert(params.name == 'kate')
local res, params = router:match('/name/kate/age/23', 'GET')
assert(res == 'person')
assert(params.name == 'kate')
assert(params.age == 23)
assert(router:match('/name', 'GET') == 'name')

local res, params = router:match('/repo/my_repo/path/lib/resty/router.lua', 'GET')
assert(res == 'rest')
assert(params.repo == 'my_repo')
assert(params.path == '/lib/resty/router.lua')

local tree = Router:new()
tree:insert('/v1', 'v1')
tree:post('/v2', 'v2')
assert(tree:match('/v1', 'GET') == 'v1')
assert(tree:match('/v2', 'POST') == 'v2')
assert(tree:match('/v2', 'GET') == nil)

-- 添加一个日志插件
router:use(function(ctx)
  print("M1 Before request")
  ctx.time = ngx.now()
  -- error("M1 error")
  ctx.yield()
  print("M1 After request")
end)

-- 添加一个计时插件
router:use(function(ctx)
  print("M2 Before request")
  local start = ngx.now()
  ctx.yield()
  ctx.time = ngx.now() - start
  print("M2 After request")
end)

-- 添加路由
-- router:get("/hello", function(ctx)
--   return "Hello World：" .. ctx.time
-- end)
router:get("/hello", setmetatable({ time = 1 }, {
  __call = function(_, ctx)
    return "Hello World111：" .. ngx.ERR
  end
}))
-- 运行路由
local result = router:dispatch("/hello", "GET")
print(result)
print('all tests passed')
