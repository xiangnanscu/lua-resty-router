return {
  -- 数组形式的多路由定义
  { "bloggers", function()
    return {
      { id = 1, name = "Alice" },
      { id = 2, name = "Bob" }
    }
  end },

  { "bloggers/:name", function(ctx)
    return {
      name = ctx.params.name
    }
  end },

  { "bloggers/#id/posts", function(ctx)
    return {
      user_id = ctx.params.id,
      posts = {
        { id = 1, title = "Post 1" },
        { id = 2, title = "Post 2" }
      }
    }
  end }
}
