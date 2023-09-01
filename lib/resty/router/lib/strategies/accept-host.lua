local function HostStorage()
  local hosts = {}
  local regexHosts = {}

  return {
    get = function(host)
      local exact = hosts[host]
      if exact then
        return exact
      end

      for _, regex in ipairs(regexHosts) do
        if regex.host:match(host) then
          return regex.value
        end
      end
    end,

    set = function(host, value)
      if type(host) == 'table' and getmetatable(host) == RegExp then
        regexHosts[#regexHosts + 1] = { host = host, value = value }
      else
        hosts[host] = value
      end
    end
  }
end

return {
  name = 'host',
  mustMatchWhenDerived = false,
  storage = HostStorage,
  validate = function(value)
    assert(type(value) == 'string' or tostring(value) == '[object RegExp]', 'Host should be a string or a RegExp')
  end
}
