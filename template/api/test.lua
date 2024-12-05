local function hello(ctx)
  return "Hello World!"
end

-- Callable table
local callable_handler = setmetatable({
  message = "Called from table"
}, {
  __call = function(self, ctx)
    return self.message
  end
})

-- HTML string handler
local html_handler = [[
<html>
<head><title>Test Page</title></head>
<body>
  <h1>Hello from HTML</h1>
</body>
</html>
]]

-- JSON response handler
local function json_handler(ctx)
  return {
    status = "success",
    data = {
      message = "JSON Response",
      timestamp = os.time()
    }
  }
end

-- Dynamic parameter handler
local function param_handler(ctx)
  return string.format("User ID: %s", ctx.params.id)
end

-- Return routes as hash group
return {
  -- Simple string response
  hello = hello,

  -- Callable table response
  callable = callable_handler,

  -- HTML response
  page = html_handler,

  -- JSON response
  api = json_handler,

  -- Route with parameters
  ["user/#id"] = param_handler,

  -- Direct string response
  about = "About Page Content"
}
