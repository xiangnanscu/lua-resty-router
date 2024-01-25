local bit = bit
local ngx_re_match = ngx.re.match
local gmatch = string.gmatch
local ipairs = ipairs
local tonumber = tonumber
local byte = string.byte


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
local dynamic_sign = {
  [35] = true, --#
  [58] = true, --:
  [60] = true, --<
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

local function _set_match_keys(tree)
  if tree.children then
    local keys = {}
    local number_keys = {}
    local regex_keys = {}
    local fallback_keys = {}
    for key, child in pairs(tree.children) do
      if byte(key) == 35 then -- 35 is ASCII value of '#'
        number_keys[#number_keys + 1] = function(node, part, params)
          local n = tonumber(part)
          if n then
            params[key:sub(2)] = n
            return node.children[key]
          end
        end
      elseif byte(key) == 58 then -- 58 is ASCII value of ':'
        fallback_keys[#fallback_keys + 1] = function(node, part, params)
          params[key:sub(2)] = part
          return node.children[key]
        end
      elseif byte(key) == 60 then -- 60 is ASCII value of '<'
        regex_keys[#regex_keys + 1] = function(node, part, params)
          local pair_index = key:find('>', 1, true)
          local re = key:sub(pair_index + 1)
          if ngx_re_match(part, re, 'josui') then
            params[key:sub(2, pair_index - 1)] = part
            return node.children[key]
          end
        end
      end
      _set_match_keys(child)
    end
    for _, groups in ipairs({ number_keys, regex_keys, fallback_keys }) do
      for _, key in ipairs(groups) do
        keys[#keys + 1] = key
      end
    end
    if #keys > 0 then
      if #keys == 1 then
        tree.match_keys = keys[1]
      else
        tree.match_keys = function(node, part, params)
          for _, func in ipairs(keys) do
            local child = func(node, part, params)
            if child then
              return child
            end
          end
        end
      end
    end
  end
end

---@alias Route {[1]:string, [2]:function|string, [3]?:string|string[]}

---@class Router
---@field handler? function|string
---@field match_keys? function
---@field children? {string:Router}
---@field methods? number
local Router = {}
Router.__index = Router

function Router:new()
  return setmetatable({ children = {} }, Router)
end

---init a router with routes
---@param routes Route[]
---@return Router
function Router:create(routes)
  local tree = Router:new()
  for _, route in ipairs(routes) do
    tree:_insert(route[1], route[2], route[3])
  end
  _set_match_keys(tree)
  return tree
end

---@param path string
---@param handler function|string
---@param methods? string|string[]
---@return Router
function Router:insert(path, handler, methods)
  local node = self:_insert(path, handler, methods)
  _set_match_keys(node)
  return node
end

function Router:post(path, handler)
  return self:insert(path, handler, 'post')
end

function Router:get(path, handler)
  return self:insert(path, handler, 'GET')
end

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
    -- / => empty, /foo => {"foo"}, /foo/ => {"foo"}
    for part in gmatch(path, "[^/]+") do
      if not node.children then
        node.children = {}
      end
      if not node.children[part] then
        node.children[part] = {}
      end
      node = node.children[part]
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
---@return function|string, {[string]: string|number}?
---@overload fun(string, string): nil, string, number
function Router:match(path, method)
  local params
  -- first try static match
  local node = self[path]
  if not node then
    node = self
    for part in gmatch(path, "[^/]+") do
      if node.children and node.children[part] then
        node = node.children[part]
      elseif node.match_keys then
        if not params then
          params = {}
        end
        node = node:match_keys(part, params)
        if not node then
          return nil, 'page not found', 404
        end
      else
        return nil, 'page not found', 404
      end
    end
  end
  if not node.methods then
    return node.handler, params
  end
  local method_bit = method_bitmask[method]
  if bit.band(node.methods, method_bit) ~= 0 then
    return node.handler, params
  else
    return nil, 'method not allowed', 405
  end
end

return Router
