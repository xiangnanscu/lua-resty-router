-- local table_sort = table.sort
local tostring = tostring


local function rawpairs(t)
  return next, t, nil
end

local function isIdentifier(str)
  return type(str) == "string" and str:match("^[_%a][_%a%d]*$")
end

-- Apostrophizes the string if it has quotes, but not aphostrophes
-- Otherwise, it returns a regular quoted string
local function smartQuote(str)
  if str:match('"') and not str:match("'") then
    return "'" .. str .. "'"
  end
  return '"' .. str:gsub('"', '\\"') .. '"'
end

-- \a => '\\a', \0 => '\\0', 31 => '\31'
local shortControlCharEscapes = {
  ["\a"] = "\\a",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
  ["\v"] = "\\v"
}
local longControlCharEscapes = {} -- \a => nil, \0 => \000, 31 => \031
for i = 0, 31 do
  local ch = string.char(i)
  if not shortControlCharEscapes[ch] then
    shortControlCharEscapes[ch] = "\\" .. i
    longControlCharEscapes[ch] = string.format("\\%03d", i)
  end
end

local function serializeString(str)
  return smartQuote(str:gsub("\\", "\\\\"):gsub("(%c)%f[0-9]", longControlCharEscapes):gsub("%c",
    shortControlCharEscapes))
end

local function isSequenceKey(k, sequenceLength)
  return type(k) == "number" and 1 <= k and k <= sequenceLength and math.floor(k) == k
end

-- For implementation reasons, the behavior of rawlen & # is "undefined" when
-- tables aren't pure sequences. So we implement our own # operator.
local function getSequenceLength(t)
  local len = 1
  local v = rawget(t, len)
  while v ~= nil do
    len = len + 1
    v = rawget(t, len)
  end
  return len - 1
end

local defaultTypeOrders = {
  ["number"] = 1,
  ["boolean"] = 2,
  ["string"] = 3,
  ["table"] = 4,
  ["function"] = 5,
  ["userdata"] = 6,
  ["thread"] = 7
}

local function sortKeys(a, b)
  local ta, tb = type(a), type(b)

  -- strings and numbers are sorted numerically/alphabetically
  if ta == tb and (ta == "string" or ta == "number") then
    return a < b
  end

  local dta, dtb = defaultTypeOrders[ta], defaultTypeOrders[tb]
  -- Two default types are compared according to the defaultTypeOrders table
  if dta and dtb then
    return defaultTypeOrders[ta] < defaultTypeOrders[tb]
  elseif dta then
    return true  -- default types before custom ones
  elseif dtb then
    return false -- custom types after default ones
  end

  -- custom types are sorted out alphabetically
  return ta < tb
end

local function getNonSequentialKeys(t)
  local keys, keysLength = {}, 0
  local sequenceLength = getSequenceLength(t)
  for k, _ in rawpairs(t) do
    if not isSequenceKey(k, sequenceLength) then
      keysLength = keysLength + 1
      keys[keysLength] = k
    end
  end
  table.sort(keys, sortKeys)
  return keys, keysLength, sequenceLength
end

local numberOrBoolean = { number = 1, boolean = 2 }

local function isArray(t)
  local n = getSequenceLength(t)
  for k, v in rawpairs(t) do
    if not isSequenceKey(k, n) then
      return false
    end
  end
  return true
end

local function zfill(s, n, c, left)
  s = tostring(s)
  local len = #s
  n = n or len
  c = c or " "
  for i = 1, n - len do
    if left then
      s = c .. s
    else
      s = s .. c
    end
  end
  return s
end

local function make_spaces(num)
  local res = ""
  for i = 1, num or 1 do
    res = res .. " "
  end
  return res
end

local function rawTostring(t)
  if type(t) == "table" then
    local mt = getmetatable(t)
    setmetatable(t, nil)
    local res = tostring(t)
    setmetatable(t, mt)
    return res
  else
    return tostring(t)
  end
end

local function serializeKey(o)
  local k = type(o)
  if k == "string" then
    if isIdentifier(o) then
      return o
    else
      return serializeString(o)
    end
  elseif numberOrBoolean[k] then
    return o
  else
    return '"' .. rawTostring(o) .. '"'
  end
end

local function serializeNonTableValue(o)
  local k = type(o)
  if k == "string" then
    return serializeString(o)
  elseif numberOrBoolean[k] then
    return tostring(o)
  else
    return '"' .. rawTostring(o) .. '"'
  end
end

local symbol = {}
symbol.__index = symbol
symbol.__tostring = function(t)
  return tostring(t[1])
end
function symbol.new(cls, str)
  return setmetatable({ str }, cls)
end

local function __call_repr(cls, ...)
  local res = {}
  for _, value in ipairs({ ... }) do
    res[#res + 1] = cls:new():dump(value)
  end
  return table.concat(res, cls.joiner)
end

local function getCommentTableAddress(t)
  return string.format("/*%s*/", rawTostring(t):sub(10))
end

local repr = {
  joiner = ' ',
  symbol = symbol,
  indent = 2,
  max_depth = math.huge
  -- show_index = 1,
}
setmetatable(repr, { __call = __call_repr })
repr.__index = repr
repr.__call = __call_repr
repr.hide_address = true
function repr.new(cls, self)
  return setmetatable(self or {}, cls)
end

function repr.doArray(self, t, indent, deep, visited)
  local addr = self.hide_address and "" or getCommentTableAddress(t)
  -- visited[t] = string.format("[%s]", addr)
  local res = {}
  local key_indent = make_spaces(indent)
  for i, v in ipairs(t) do
    res[#res + 1] = string.format("%s%s,", key_indent, self:dump(v, indent + self.indent, deep + 1, visited))
  end
  return string.format("[\n%s%s%s\n%s]", self.hide_address and "" or key_indent,
    addr .. (self.hide_address and "" or "\n"), table.concat(res, "\n"), make_spaces(indent - self.indent))
end

function repr.doDict(self, t, indent, deep, visited)
  local addr = self.hide_address and "" or getCommentTableAddress(t)
  -- visited[t] = string.format("{%s}", addr)
  local res = {}
  local normalize = {}
  local max_key_len = 0
  for k, v in rawpairs(t) do
    k = serializeKey(k)
    local n = #tostring(k)
    if n > max_key_len then
      max_key_len = n
    end
    normalize[k] = self:dump(v, indent + self.indent, deep + 1, visited)
  end
  t = normalize
  local key_indent = make_spaces(indent)
  local nonSequentialKeys, nonSequentialKeysLength, sequenceLength = getNonSequentialKeys(t)
  for i = 1, sequenceLength do
    res[#res + 1] = string.format("%s%s: %s,", key_indent, zfill(i, max_key_len), t[i])
  end
  for i = 1, nonSequentialKeysLength do
    local k = nonSequentialKeys[i]
    res[#res + 1] = string.format("%s%s: %s,", key_indent, zfill(k, max_key_len), t[k])
  end
  return string.format("{\n%s%s%s\n%s}", self.hide_address and "" or key_indent,
    addr .. (self.hide_address and "" or "\n"), table.concat(res, "\n"), make_spaces(indent - self.indent))
end

function repr.string(cls, o)
  return cls:new { hide_address = false }:dump(type(o) == "table" and o or symbol:new(o))
end

function repr.dump(self, o, indent, deep, visited)
  indent = indent or self.indent
  deep = deep or 1
  visited = visited or {}
  if type(o) == "table" then
    if visited[o] then
      return visited[o]
    end
    local addr = self.hide_address and "" or getCommentTableAddress(o)
    if getmetatable(o) == symbol then
      return tostring(o)
    elseif isArray(o) then
      if deep > self.max_depth then
        return "[/*max deepth reached*/]"
      end
      visited[o] = string.format("[%s]", addr)
      return self:doArray(o, indent, deep, visited)
    else
      if deep > self.max_depth then
        return "{/*max deepth reached*/}"
      end
      visited[o] = string.format("{%s}", addr)
      return self:doDict(o, indent, deep, visited)
    end
  else
    return serializeNonTableValue(o)
  end
end

repr.serializeNonTableValue = serializeNonTableValue
repr.isArray = isArray

return repr
