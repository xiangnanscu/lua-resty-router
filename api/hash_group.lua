return {
  -- 映射形式的路由定义
  list = function()
    return {
      { id = 1, type = "item1" },
      { id = 2, type = "item2" }
    }
  end,

  ["detail/#id"] = function(ctx)
    return {
      id = ctx.params.id,
      type = "detail",
      description = "Item details"
    }
  end,

  ["search/:keyword"] = function(ctx)
    return {
      keyword = ctx.params.keyword,
      results = {
        { id = 1, match = true },
        { id = 2, match = false }
      }
    }
  end
}
