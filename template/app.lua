local Router = require('resty.router')

local router = Router:new()

router:get('/', function(ctx)
  ctx.response.status = 200
  ctx.response.body = 'Hello, World!'
end)

return router
