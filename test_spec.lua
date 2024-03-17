local Router = require('./lib/resty/router')
local tree = Router:create {
  { '/',                         'root',    { 'GET', 'patch' } },
  { '/v1',                       'v1',      'GET' },
  { '/number/#age',              'age',     'GET' },
  { '/all/:name',                'name',    'GET' },
  { '/regex/<version>\\d+-\\d+', 'version', 'GET' },
  { '/name',                     'name',    'GET' },
  { '/name/:name/age/#age',      'person',  'GET' },
  { '/v2',                       'v2',      'post' },
  { '/repo/:repo/path/*path',    'rest',    'get' },
}

local res, err, status = tree:match('/', 'POST')
assert(res == nil and err == 'method not allowed' and status == 405)
local res, params, status = tree:match('/v2/foo', 'GET')
assert(res == nil and params == 'page not found' and status == 404)
assert(tree:match('/', 'GET') == tree:match('/', 'PATCH'))
assert(tree:match('/v1', 'GET') == 'v1')
local res, params = tree:match('/number/#age', 'GET')
assert(res == 'age')
assert(params == nil)
local res, params = tree:match('/number/23', 'GET')
assert(res == 'age', 'res is :' .. tostring(res))
assert(params.age == 23)
local res, params = tree:match('/regex/1-3', 'GET')
assert(res == 'version')
assert(params.version == '1-3')
local res, params = tree:match('/all/kate', 'GET')
assert(res == 'name')
assert(params.name == 'kate')
local res, params = tree:match('/name/kate/age/23', 'GET')
assert(res == 'person')
assert(params.name == 'kate')
assert(params.age == 23)
assert(tree:match('/name', 'GET') == 'name')

local res, params = tree:match('/repo/my_repo/path/lib/resty/router.lua', 'GET')
assert(res == 'rest')
assert(params.repo == 'my_repo')
assert(params.path == '/lib/resty/router.lua')

local tree = Router:new()
tree:insert('/v1', 'v1')
tree:post('/v2', 'v2')
assert(tree:match('/v1', 'GET') == 'v1')
assert(tree:match('/v2', 'POST') == 'v2')
assert(tree:match('/v2', 'GET') == nil)

print('all tests passed')
