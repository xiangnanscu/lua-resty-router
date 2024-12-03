local Router = require('resty.router')

local router = Router:new()

-- 测试插件
router:use(function(ctx)
  ctx.plugin_executed = true
  ctx:yield()
end)

-- 测试事件
router:on('success', function(ctx)
  -- ngx.log(ngx.INFO, "请求成功")
end)

router:on('error', function(ctx)
  -- ngx.log(ngx.INFO, "请求失败")
end)

-- 1. 测试静态路径
router:get("/hello", function()
  return "Hello World"
end)

-- 2. 测试JSON响应
router:get("/json", function()
  return { message = "success", code = 0 }
end)

-- 3. 测试动态路径参数
router:get("/users/#id", function(ctx)
  return {
    id = ctx.params.id,
    type = "number"
  }
end)

router:get("/users/:name", function(ctx)
  return {
    name = ctx.params.name,
    type = "string"
  }
end)

-- 4. 测试正则路径
router:get("/version/<ver>\\d+\\.\\d+", function(ctx)
  return {
    version = ctx.params.ver
  }
end)

-- 5. 测试通配符
router:get("/files/*path", function(ctx)
  return {
    path = ctx.params.path
  }
end)

-- 6. 测试多个HTTP方法
router:post("/accounts", function(ctx)
  return { method = "POST" }
end)

router:put("/accounts/#id", function(ctx)
  return { method = "PUT", id = ctx.params.id }
end)

-- 7. 测试错误处理
router:get("/error", function()
  error("测试错误")
end)

-- 8. 测试状态码
router:get("/404", function()
  return nil, "Not Found", 404
end)

-- 9. 测试HTML响应
router:get("/html", function()
  return "<h1>Hello HTML</h1>"
end)

-- 10. 测试函数返回
router:get("/func", function()
  return function()
    ngx.say("function called")
    return true
  end
end)
ngx.log(ngx.ERR, require("resty.repr")(router))
return router
