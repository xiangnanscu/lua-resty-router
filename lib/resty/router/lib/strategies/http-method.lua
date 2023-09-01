return {
  name = '__fmw_internal_strategy_merged_tree_http_method__',
  storage = function()
    local handlers = {}

    return {
      get = function(type)
        return handlers[type] or nil
      end,

      set = function(type, store)
        handlers[type] = store
      end
    }
  end,

  deriveConstraint = function(req)
    -- istanbul ignore next
    return req.method
  end,

  mustMatchWhenDerived = true
}
