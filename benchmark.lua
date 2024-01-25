local v1 = require('resty.rax')
local v2 = require("./lib/resty/router")

local function p(s)
  print(require("resty.inspect")(s))
end
local names = {
  'actions',
  'ad',
  'admin',
  'alioss_payload',
  'badge_number',
  'branch',
  'branch_login',
  'classview',
  'env',
  'feeplan',
  'forum',
  'friends',
  'goddess',
  'goddess_comment',
  'goddess_comment_comment',
  'h1',
  'hello',
  'hik',
  'home_data',
  'login_h5',
  'logs',
  'message',
  'news',
  'oauth',
  'orders',
  'parent',
  'parent_student_relation',
  'permission_view',
  'poll',
  'poll_log',
  'post',
  'post_comment',
  'prizebook',
  'school',
  'session',
  'settings',
  'shyk',
  'stage',
  'stage_apply',
  'stat',
  'student',
  'subscribe',
  'system_message',
  'teacher',
  'test',
  'thread',
  'update_profile',
  'usr',
  'usr_login',
  'volplan',
  'volreg',
  'wx',
  'wx_login',
  'wx_phone',
  'wxqy_directives',
  'wxqy_events',
  'wxqy_validate_domain',
  'youth_branch_login',
  'youth_fee',
  'youth_member',
  'youth_member_delete_apply',
}

local routes1 = {}
local routes2 = {}

local args = {}
for index, name in ipairs(names) do
  local url = string.format('/%s/records', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/json', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/create', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/detail/#id/age/:age', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/update/#id/time/:time', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/delete/#id/age/:age', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/download', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/merge', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/choices', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/filter', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
  local url = string.format('/%s/get', name)
  args[#args + 1] = { url, url, { 'get', 'post' } }
end

for index, value in ipairs(args) do
  routes1[#routes1 + 1] = { path = value[1], handler = value[2], methods = value[3] }
end
local t1 = v1.new(routes1)
local t2 = v2:create(args)

local function timeit(func, n)
  n = n or 1
  func()
  local start = os.clock() -- 获取初始时间
  for i = 1, n do
    func()
  end
  local finish = os.clock()            -- 获取结束时间
  local executionTime = finish - start -- 计算运行时间
  print(string.format("Execution time: %.4f seconds", executionTime))
end
local function f(s)

end
local function v1t()
  for index, name in ipairs(names) do
    local u1 = string.format('/%s/detail/1/age/18', name)
    local res, params = t1:match(u1, 'GET')
    assert(params.age == '18' and params.id == '1')
    local u2 = string.format('/%s/update/1/time/18', name)
    local res, params = t1:match(u2, 'GET')
    assert(params.time == '18' and params.id == '1')
    local u3 = string.format('/%s/delete/1/age/118', name)
    local res, params = t1:match(u3, 'GET')
    assert(params.age == '118' and params.id == '1')
  end
end
local function v2t()
  for index, name in ipairs(names) do
    local u1 = string.format('/%s/detail/1/age/18', name)
    local res, params = t2:match(u1, 'GET')
    assert(params)
    assert(params.age == '18' and params.id == 1)
    local u2 = string.format('/%s/update/1/time/18', name)
    local res, params = t2:match(u2, 'GET')
    assert(params)
    assert(params.time == '18' and params.id == 1)
    local u3 = string.format('/%s/delete/1/age/118', name)
    local res, params = t2:match(u3, 'GET')
    assert(params)
    assert(params.age == '118' and params.id == 1)
  end
end
timeit(v1t, 20000)
timeit(v2t, 20000)
