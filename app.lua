local Router = require('resty.router')

local router = Router:new()

local success_cnt = 0
local error_cnt = 0


-- 测试事件
router:on('success', function(ctx)
  success_cnt = success_cnt + 1
end)

router:on('error', function(ctx)
  error_cnt = error_cnt + 1
end)

-- 测试插件
router:use(function(ctx)
  ctx.success_cnt = success_cnt
  ctx.error_cnt = error_cnt
end)

-- 1. 测试静态路径
router:get("/hello", function()
  return "Hello World"
end)

-- 测试自定义成功状态码
router:get("/hello-201", function()
  return "Hello World", 201
end)

-- 2. 测试JSON响应
router:get("/json", function()
  return { message = "success", code = 0 }
end)

-- 3. 测试动态路径参数
router:get("/users/#id", function(ctx)
  return {
    id = ctx.params.id,
    type = type(ctx.params.id)
  }
end)

router:get("/users/:name", function(ctx)
  return {
    name = ctx.params.name,
    type = type(ctx.params.name)
  }
end)

-- 4. 测试正则路径
router:get([[/version/<ver>\d+\.\d+]], function(ctx)
  return {
    version = ctx.params.ver
  }
end)

-- 5. 测试通配符
router:get("/files/*path", function(ctx)
  return ctx.params.path
end)

-- 6. 测试其他HTTP方法
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

-- 测试error抛出的自定义错误
router:get("/custom-error", function()
  error({ code = 400, message = "自定义错误" })
end)

-- 测试return nil, err, code形式的错误
router:get("/return-error", function()
  return nil, "参数错误", 402
end)

-- 测试handled error
router:get("/handled-error", function()
  error { "handled error" }
end)

-- 8. 测试状态码
router:get("/404", function()
  return nil, "Not Found", 404
end)

-- 9. 测试HTML响应
router:get("/html", function()
  return "<h1>Hello HTML</h1>"
end)
-- 测试html错误
router:get("/html-error", function()
  return nil, "<h1>Hello HTML error</h1>", 501
end)
-- 测试error抛出的html错误
router:get("/html-error2", function()
  error { "<h1>Hello HTML error2</h1>" }
end)

-- 10. 测试函数返回
router:get("/func", function(ctx)
  return function()
    ngx.header.content_type = 'text/plain; charset=utf-8'
    ngx.say("function called2")
  end
end)

-- 11. 查看events是否正常执行
router:get("/events", function(ctx)
  return {
    success_cnt = ctx.success_cnt,
    error_cnt = ctx.error_cnt
  }
end)

-- ngx.log(ngx.ERR, require("resty.repr")(router))
return router
