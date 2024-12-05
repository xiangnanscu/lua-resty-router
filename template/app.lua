local Router = require('resty.router')

local router = Router:new()

router:get('/', function(ctx)
  return [[<html>
      <head>
        <style>
          body {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(120deg, #84fab0 0%, #8fd3f4 100%);
            font-family: Arial, sans-serif;
          }
          .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.9);
            border-radius: 10px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
          }
          h1 {
            color: #2c3e50;
            font-size: 3rem;
            margin-bottom: 1rem;
          }
          p {
            color: #34495e;
            font-size: 1.5rem;
            margin-bottom: 2rem;
          }
          .api-list {
            text-align: left;
            max-width: 500px;
            margin: 0 auto;
          }
          .api-item {
            background: rgba(255, 255, 255, 0.7);
            padding: 1rem;
            margin: 0.5rem 0;
            border-radius: 5px;
            transition: all 0.3s ease;
          }
          .api-item:hover {
            background: rgba(255, 255, 255, 0.9);
            transform: translateX(5px);
          }
          a {
            color: #2980b9;
            text-decoration: none;
            display: block;
          }
          a:hover {
            color: #3498db;
          }
          .method {
            display: inline-block;
            padding: 0.2rem 0.5rem;
            border-radius: 3px;
            font-size: 0.8rem;
            margin-right: 0.5rem;
            background: #3498db;
            color: white;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🎉🎉🎉🎉 Congratulations!</h1>
          <p>Your resty application is running</p>
          <div class="api-list">
            <div class="api-item">
              <a href="/test/hello"><span class="method">GET</span> /test/hello - Simple String Response</a>
            </div>
            <div class="api-item">
              <a href="/test/callable"><span class="method">GET</span> /test/callable - Callable Table Response</a>
            </div>
            <div class="api-item">
              <a href="/test/page"><span class="method">GET</span> /test/page - HTML Page Response</a>
            </div>
            <div class="api-item">
              <a href="/test/api"><span class="method">GET</span> /test/api - JSON API Response</a>
            </div>
            <div class="api-item">
              <a href="/test/user/123"><span class="method">GET</span> /test/user/#id - Route with Parameters</a>
            </div>
            <div class="api-item">
              <a href="/test/about"><span class="method">GET</span> /test/about - Direct String Response</a>
            </div>
            <div class="api-item">
              <a href="/users"><span class="method">GET</span> /users - User List</a>
            </div>
          </div>
        </div>
      </body>
    </html>
  ]]
end)

-- add routes from lua files in api folder
router:fs('./api')

return router
