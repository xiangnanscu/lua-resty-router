local encode         = require "cjson.safe".encode
local bit            = bit
local gmatch         = string.gmatch
local ipairs         = ipairs
local tonumber       = tonumber
local byte           = string.byte
local ngx_re_match   = ngx.re.match
local coroutine      = coroutine
local resume         = coroutine.resume
local trace_back     = debug.traceback
local ngx            = ngx
local ngx_header     = ngx.header
local ngx_print      = ngx.print
local ngx_var        = ngx.var
local string_format  = string.format
local xpcall         = xpcall
local spawn          = ngx.thread.spawn

local method_bitmask = {
  GET = 1,       -- 2^0
  POST = 2,      -- 2^1
  PATCH = 4,     -- 2^2
  PUT = 8,       -- 2^3
  DELETE = 16,   -- 2^4
  HEAD = 32,     -- 2^5
  OPTIONS = 64,  -- 2^6
  CONNECT = 128, -- 2^7
}
local dynamic_sign   = {
  [35] = true, --#
  [58] = true, --:
  [60] = true, --<
  [42] = true, --*
}
local function methods_to_bitmask(methods)
  local bitmask = 0
  for _, method in ipairs(methods) do
    bitmask = bit.bor(bitmask, method_bitmask[method:upper()])
  end
  return bitmask
end

local function is_static_path(path)
  for part in gmatch(path, "[^/]+") do
    if dynamic_sign[byte(part)] then
      return false
    end
  end
  return true
end

local function _set_find_method(tree)
  if not tree.children then
    return
  end
  local methods = {}
  -- group keys for matching priority, i.e: /v1/#age, /v1/<version>\\d+-\\d+, /v1/:name, /v1/*path
  local number_methods = {}
  local regex_methods = {}
  local char_methods = {}
  local fallback_methods = {}
  for key, child in pairs(tree.children) do
    local bkey = byte(key)
    if bkey == 35 then -- 35 is ASCII value of '#'
      number_methods[#number_methods + 1] = function(node, part, params)
        local n = tonumber(part)
        if n then
          params[key:sub(2)] = n
          return node.children[key]
        end
      end
    elseif bkey == 60 then -- 60 is ASCII value of '<'
      local pair_index = key:find('>', 1, true)
      local regex = key:sub(pair_index + 1)
      local regex_key = key:sub(2, pair_index - 1)
      regex_methods[#regex_methods + 1] = function(node, part, params)
        local m = ngx_re_match(part, regex, 'josui')
        if m then
          params[regex_key] = m[0]
          return node.children[key]
        end
      end
    elseif bkey == 58 then -- 58 is ASCII value of ':'
      char_methods[#char_methods + 1] = function(node, part, params)
        params[key:sub(2)] = part
        return node.children[key]
      end
    elseif bkey == 42 then -- 42 is ASCII value of '*'
      tree.match_rest = true
      fallback_methods[#fallback_methods + 1] = function(node, part, params)
        params[key:sub(2)] = part
        return node.children[key]
      end
    end
    _set_find_method(child)
  end
  for _, groups in ipairs({ number_methods, regex_methods, char_methods, fallback_methods }) do
    for _, key in ipairs(groups) do
      methods[#methods + 1] = key
    end
  end
  if #methods > 0 then
    if #methods == 1 then
      tree._find = methods[1]
    else
      tree._find = function(node, part, params)
        for _, func in ipairs(methods) do
          local child = func(node, part, params)
          if child then
            return child
          end
        end
      end
    end
  end
end

---@alias Route {[1]:string|string[], [2]:function|string, [3]?:string|string[]}

---@class Router
---@field private handler function|string|table
---@field private _find? function
---@field private children? {string:Router}
---@field private methods? number
---@field private match_rest? boolean
---@field private plugins function[]
---@field private events {string:function}
---@field private __index Router
---@field get fun(self:Router, path:string|table, handler:function|string|table): Router
---@field post fun(self:Router, path:string|table, handler:function|string|table): Router
---@field patch fun(self:Router, path:string|table, handler:function|string|table): Router
---@field put fun(self:Router, path:string|table, handler:function|string|table): Router
---@field delete fun(self:Router, path:string|table, handler:function|string|table): Router
---@field head fun(self:Router, path:string|table, handler:function|string|table): Router
---@field options fun(self:Router, path:string|table, handler:function|string|table): Router
---@field connect fun(self:Router, path:string|table, handler:function|string|table): Router
local Router = { method_bitmask = method_bitmask }
Router.__index = Router

function Router:new()
  return setmetatable({ children = {}, plugins = {}, events = {} }, Router)
end

function Router:is_handler(handler)
  if type(handler) == 'function' or type(handler) == 'string' then
    return true
  end
  if type(handler) ~= 'table' then
    return nil, 'route handler should be a function or string or table, not ' .. type(handler)
  end
  local meta = getmetatable(handler)
  if not meta or not meta.__call then
    return nil, 'route handler is not a callable table'
  end
  return true
end

function Router:is_route(view)
  if type(view) ~= 'table' then
    return nil, "route must be a table"
  end
  if type(view[1]) == 'table' then
    if #view[1] == 0 then
      return nil, "the first element of route is a table can't be empty"
    end
    for _, p in ipairs(view[1]) do
      if type(p) ~= 'string' then
        return nil, "the path should be a string, not " .. type(p)
      end
    end
  elseif type(view[1]) ~= 'string' then
    return nil, 'the first element of route should be a string or table, not ' .. type(view[1])
  end
  if view[3] ~= nil then
    if type(view[3]) == 'string' then
      if not method_bitmask[view[3]:upper()] then
        return nil, 'invalid http method: ' .. view[3]
      end
    elseif type(view[3]) == 'table' then
      for _, method in ipairs(view[3]) do
        if type(method) ~= 'string' then
          return nil, 'the method should be string only, not ' .. type(method)
        end
        if not method_bitmask[method:upper()] then
          return nil, 'invalid http method: ' .. method
        end
      end
    else
      return nil, 'the method argument should be a string or table, not ' .. type(view[3])
    end
  end
  return self:is_handler(view[2])
end

---init a router with routes
---@param routes Route[]
---@return Router
function Router:create(routes)
  local tree = Router:new()
  for _, route in ipairs(routes) do
    assert(self:is_route(route))
    local path = route[1]
    if type(path) == 'string' then
      tree:_insert(path, route[2], route[3])
    else
      for _, p in ipairs(path) do
        tree:_insert(p, route[2], route[3])
      end
    end
  end
  _set_find_method(tree)
  return tree
end

---@param path string|table
---@param handler function|string
---@param methods? string|string[]
---@return Router
function Router:insert(path, handler, methods)
  if type(path) == 'table' then
    if handler == nil then
      assert(self:is_route(path))
      return self:insert(unpack(path))
    else
      local node
      for _, p in ipairs(path) do
        node = self:insert(p, handler, methods)
      end
      return node
    end
  else
    assert(self:is_route { path, handler, methods })
    local node = self:_insert(path, handler, methods)
    _set_find_method(self)
    return node
  end
end

---@private
---@param path string
---@param handler function|string
---@param methods? string|string[]
---@return Router
function Router:_insert(path, handler, methods)
  local node = self
  if is_static_path(path) then
    node[path] = {}
    node = node[path]
  else
    local parts = {}
    for part in gmatch(path, "[^/]+") do
      parts[#parts + 1] = part
    end
    for i, part in ipairs(parts) do
      if not node.children then
        node.children = {}
      end
      if not node.children[part] then
        ---@diagnostic disable-next-line: missing-fields
        node.children[part] = {}
      end
      node = node.children[part]
      if byte(part) == 42 then -- 42 is ASCII value of '*'
        assert(i == #parts, 'Catch-all routes are only supported as the last part of the path')
        break
      end
    end
  end
  node.handler = assert(handler, 'you must provide a handler')
  if type(methods) == 'string' then
    node.methods = bit.bor(0, method_bitmask[methods:upper()])
  elseif type(methods) == 'table' then
    node.methods = methods_to_bitmask(methods)
  end
  return node
end

---match a http request
---@param path string
---@param method string
---@return function|string|table, {[string]: string|number}?
---@overload fun(string, string): nil, number
function Router:match(path, method)
  local params
  -- first try static match
  local node = self[path]
  if not node then
    node = self
    local cut = 1
    for part in gmatch(path, "[^/]+") do
      if node.children and node.children[part] then
        node = node.children[part]
      elseif node._find then
        if not params then
          params = {}
        end
        if not node.match_rest then
          node = node:_find(part, params)
          if not node then
            return nil, 404
          end
        else
          node = node:_find(path:sub(cut), params)
          if not node then
            return nil, 404
          else
            break
          end
        end
      else
        return nil, 404
      end
      cut = cut + #part + 1
    end
  end
  if not node.handler then
    -- defined /update/#id, but match /update
    return nil, 404
  end
  if not node.methods then
    return node.handler, params
  end
  local method_bit = method_bitmask[method]
  if bit.band(node.methods, method_bit) ~= 0 then
    return node.handler, params
  else
    return nil, 405
  end
end

for method, _ in pairs(method_bitmask) do
  ---@diagnostic disable-next-line: assign-type-mismatch
  Router[method:lower()] = function(self, path, handler)
    return self:insert(path, handler, method)
  end
end

---@param plugin function
function Router:use(plugin)
  assert(type(plugin) == 'function', "plugin must be a function")
  self.plugins[#self.plugins + 1] = plugin
end

function Router:on(event_key, handler)
  self.events[event_key] = handler
end

function Router:emit(event_key, ...)
  if self.events and self.events[event_key] then
    return spawn(self.events[event_key], ...)
  end
end

---@return table
function Router:create_context()
  return setmetatable({ yield = coroutine.yield }, ngx.req)
end

---@param path string
---@param method string
---@return boolean
---@overload fun(string, string): boolean
function Router:dispatch(path, method)
  local handler, params_or_code = self:match(path, method)
  if handler == nil then
    return self:fail('match route failed', {}, params_or_code)
  end

  local ctx = self:create_context()
  if params_or_code then
    ctx.params = params_or_code
  end

  for _, plugin in ipairs(self.plugins) do
    local co = coroutine.create(function()
      plugin(ctx)
    end)
    local ok, err = resume(co)
    if not ok then
      return self:fail(err, ctx, 500)
    end
    if coroutine.status(co) == "suspended" then
      ctx[#ctx + 1] = co
    end
  end

  if type(handler) == 'string' then
    return self:ok(handler, ctx)
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, result, err = xpcall(handler, trace_back, ctx)
    if not ok then
      return self:fail(result, ctx, 500)
    elseif result == nil then
      return self:fail(err, ctx, 500)
    else
      local resp_type = type(result)
      if resp_type == 'table' or resp_type == 'boolean' or resp_type == 'number' then
        local json, encode_err = encode(result)
        if not json then
          return self:fail(encode_err, ctx)
        else
          ngx_header.content_type = 'application/json; charset=utf-8'
          return self:ok(json, ctx)
        end
      elseif resp_type == 'string' then
        if byte(result) == 60 then -- 60 is ASCII value of '<'
          ngx_header.content_type = 'text/html; charset=utf-8'
        else
          ngx_header.content_type = 'text/plain; charset=utf-8'
        end
        return self:ok(result, ctx)
      elseif type(result) == 'function' then
        ok, result, err = xpcall(result, trace_back)
        if not ok then
          return self:fail(result, ctx, 500)
        elseif result == nil then
          return self:fail(err, ctx, 500)
        else
          return self:finish(200, ctx)
        end
      else
        return self:fail('invalid response type: ' .. resp_type)
      end
    end
  end
end

function Router:ok(body, ctx, code)
  ngx_print(body)
  code = code or 200
  return self:finish(code, ctx, ngx.exit, code)
end

function Router:fail(err, ctx, code)
  ngx_print(err)
  code = code or 500
  return self:finish(code, ctx, ngx.exit, code)
end

function Router:redirect(ctx, uri, code)
  code = code or 302
  return self:finish(code, ctx, ngx.redirect, uri, code)
end

function Router:exec(uri, args, ctx)
  return self:finish(200, ctx, ngx.exec, uri, args)
end

local function get_event_key(events, code)
  if code == ngx.OK and events.ok then
    return 'ok'
  elseif code == 499 and events.abort then
    return 'abort'
  elseif code >= 100 and code <= 199 and events.info then
    return 'info'
  elseif code >= 200 and code <= 299 and events.success then
    return 'success'
  elseif code >= 300 and code <= 399 and events.redirect then
    return 'redirect'
  elseif code >= 400 and code <= 499 and events.client_error then
    return 'client_error'
  elseif code >= 500 and code <= 599 and events.server_error then
    return 'server_error'
  elseif code >= 400 and code <= 599 and events.error then
    return 'error'
  end
end

function Router:finish(code, ctx, ngx_func, ...)
  local events = self.events
  if events[code] then
    self:emit(code, ctx)
  else
    local key = get_event_key(events, code)
    if key then
      self:emit(key, ctx)
    end
  end
  for i = #ctx, 1, -1 do
    local t = ctx[i]
    ctx[i] = nil
    resume(t)
  end
  return ngx_func(...)
end

return Router
