local json          = require "cjson.safe"
local bit           = bit
local gmatch        = string.gmatch
local ipairs        = ipairs
local tonumber      = tonumber
local byte          = string.byte
local ngx_re_match  = ngx.re.match
local coroutine     = coroutine
local resume        = coroutine.resume
local trace_back    = debug.traceback
local ngx           = ngx
local ngx_header    = ngx.header
local ngx_print     = ngx.print
local ngx_var       = ngx.var
local string_format = string.format
local xpcall        = xpcall
local spawn         = ngx.thread.spawn
local ngx_req       = ngx.req
local decode        = json.decode
local encode        = json.encode
local get_post_args = ngx.req.get_post_args
local read_body     = ngx.req.read_body
local get_body_data = ngx.req.get_body_data
local assert        = assert
local rawget        = rawget
local setmetatable  = setmetatable
local lfs
do
  local o, l = pcall(require, "syscall.lfs")
  if not o then o, l = pcall(require, "lfs") end
  if o then lfs = l end
end

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

---insert routes to a router
---@param routes Route[]
---@return Router
function Router:extend(routes)
  for _, route in ipairs(routes) do
    assert(self:is_route(route))
    local path = route[1]
    if type(path) == 'string' then
      self:_insert(path, route[2], route[3])
    else
      for _, p in ipairs(path) do
        self:_insert(p, route[2], route[3])
      end
    end
  end
  _set_find_method(self)
  return self
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

local Response = {
  header = ngx_header,
  get_headers = ngx_req.get_headers,
}
Response.__index = Response

local Context = {
  yield = coroutine.yield
}
---@private
function Context.__index(self, key)
  if Context[key] ~= nil then
    return Context[key]
  elseif ngx_req[key] ~= nil then
    return ngx_req[key]
  elseif key == 'response' then
    self.response = setmetatable({}, Response)
    return self.response
  elseif key == 'query' then
    self.query = ngx_req.get_uri_args()
    return rawget(self, 'query')
  else
    return nil
  end
end

---@return table
function Router:create_context()
  return setmetatable({}, Context)
end

---@param path string
---@param method string
---@return boolean
function Router:dispatch(path, method)
  -- before plugins
  local ctx = self:create_context()
  for _, plugin in ipairs(self.plugins) do
    local co = coroutine.create(function()
      plugin(ctx)
    end)
    local ok, err = resume(co)
    if not ok then
      return self:fail(ctx, err)
    end
    if coroutine.status(co) == "suspended" then
      ctx[#ctx + 1] = co
    end
  end
  -- match route
  local handler, params_or_code = self:match(path, method)
  if handler == nil then
    return self:echo(ctx, 'match route failed', params_or_code --[[@as number]])
  end
  if params_or_code then
    ctx.params = params_or_code
  end
  if type(handler) == 'string' then
    return self:echo(ctx, handler, 200)
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, result, err_or_okcode, errcode = xpcall(handler, trace_back, ctx)
    if not ok then
      return self:fail(ctx, result)
    elseif result == nil then
      if err_or_okcode ~= nil then
        return self:fail(ctx, err_or_okcode, errcode)
      elseif rawget(ctx, 'response') then
        local code = ctx.response.status or 200
        if ctx.response.body then
          return self:echo(ctx, ctx.response.body, code)
        else
          return self:echo(ctx, 'no response', 500)
        end
      else
        return self:echo(ctx, 'no response', 500)
      end
    elseif type(result) ~= 'function' then
      return self:echo(ctx, result, err_or_okcode or 200)
    else
      ok, result = xpcall(result, trace_back, ctx)
      if not ok then
        return self:fail(ctx, result)
      else
        return self:finish(ctx, 200, ngx.exit, 0)
      end
    end
  end
end

---success response
---@param ctx table request context
---@param body string response body
---@param code number response code
---@return unknown
function Router:echo(ctx, body, code)
  ngx.status = code
  local res, err = self:print(body)
  if res == nil then
    return self:fail(ctx, err)
  else
    return self:finish(ctx, code, ngx.exit, 0)
  end
end

---failed response
---@param ctx table request context
---@param err string|table error message
---@param code? number error code
---@return unknown
function Router:fail(ctx, err, code)
  code = code or 500
  ngx.status = code
  self:print_error(err)
  return self:finish(ctx, code, ngx.exit, 0)
end

function Router:print(body)
  if type(body) == 'string' then
    if not ngx_header.content_type then
      if byte(body) == 60 then -- 60 is ASCII value of '<'
        ngx_header.content_type = 'text/html; charset=utf-8'
      else
        ngx_header.content_type = 'text/plain; charset=utf-8'
      end
    end
    return ngx_print(body)
  elseif type(body) == 'number' or type(body) == 'boolean' then
    if not ngx_header.content_type then
      ngx_header.content_type = 'application/json; charset=utf-8'
    end
    local t, e = encode(body)
    if t then
      return ngx_print(t)
    else
      return nil, e
    end
  elseif type(body) == 'table' then
    if not ngx_header.content_type then
      ngx_header.content_type = 'application/json; charset=utf-8'
    end
    local t, e = encode(body)
    if t then
      return ngx_print(t)
    else
      return nil, e
    end
  else
    return nil, 'invalid response type: ' .. type(body)
  end
end

function Router:print_error(body)
  if type(body) == 'table' and #body == 1 and type(body[1]) == 'string' then
    if not ngx_header.content_type then
      ngx_header.content_type = 'text/plain; charset=utf-8'
    end
    return ngx_print(body[1])
  else
    return self:print(body)
  end
end

function Router:redirect(ctx, uri, code)
  code = code or 302
  return self:finish(ctx, code, ngx.redirect, uri, code)
end

function Router:exec(ctx, uri, args)
  return self:finish(ctx, ngx.OK, ngx.exec, uri, args)
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

function Router:finish(ctx, code, ngx_func, ...)
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

function Router:run()
  return self:dispatch(ngx_var.document_uri, ngx_var.request_method)
end

local function callable(handler)
  return type(handler) == "function" or
      (type(handler) == "table" and getmetatable(handler) and getmetatable(handler).__call)
end

local function is_handler(handler)
  return type(handler) == "string" or callable(handler)
end

---@param dir string Directory path to scan
---@param base_path? string Base path (used for recursion)
---@return table[] Route configuration array
function Router:collect_routes(dir, base_path)
  local routes = {}
  base_path = base_path or ""

  -- Recursively scan directory
  for file in lfs.dir(dir) do
    if file ~= "." and file ~= ".." then
      local path = dir .. "/" .. file
      local attr = lfs.attributes(path)

      if attr.mode == "directory" then
        -- Process subdirectories recursively
        local sub_routes = self:collect_routes(path, base_path .. "/" .. file)
        for _, route in ipairs(sub_routes) do
          routes[#routes + 1] = route
        end
      elseif attr.mode == "file" and file:match("%.lua$") then
        -- Process .lua files
        local module_path = path:gsub("%.lua$", ""):gsub("/", ".")
        local ok, route = pcall(require, module_path)
        if ok then
          -- Get relative path (remove .lua extension)
          local relative_path = base_path .. "/" .. file:gsub("%.lua$", "")

          -- Handle different types of route definitions
          if is_handler(route) then
            -- Type 1: Function or callable table
            routes[#routes + 1] = { relative_path, route }
          elseif type(route) == "table" then
            if #route > 0 then
              if type(route[1]) == "string" and is_handler(route[2]) then
                -- Type 2: Single route definition
                local path = route[1]
                if path:sub(1, 1) == "/" then
                  routes[#routes + 1] = { path, route[2], route[3] }
                else
                  routes[#routes + 1] = { relative_path .. "/" .. path, route[2], route[3] }
                end
              else
                -- Type 3: Array of multiple route definitions
                for _, view in ipairs(route) do
                  if type(view[1]) == "string" and is_handler(view[2]) then
                    if view[1]:sub(1, 1) == "/" then
                      routes[#routes + 1] = { view[1], view[2], view[3] }
                    else
                      routes[#routes + 1] = { relative_path .. "/" .. view[1], view[2], view[3] }
                    end
                  end
                end
              end
            else
              -- Type 4: Map-style route definitions
              for key, handler in pairs(route) do
                if type(key) == "string" and key:sub(1, 1) ~= "/" and is_handler(handler) then
                  routes[#routes + 1] = { relative_path .. "/" .. key, handler }
                end
              end
            end
          end
        end
      end
    end
  end

  return routes
end

function Router:fs(dir)
  local routes = self:collect_routes(dir)
  self:extend(routes)
end

return Router
