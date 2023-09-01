local SemVerStore = {}

function SemVerStore:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self

  obj.store = {}
  obj.maxMajor = 0
  obj.maxMinors = {}
  obj.maxPatches = {}

  return obj
end

function SemVerStore:set(version, store)
  if type(version) ~= 'string' then
    error('Version should be a string')
  end

  local major, minor, patch = string.match(version, '^(%d+)%.(%d+)%.(%d+)$')
  major = tonumber(major) or 0
  minor = tonumber(minor) or 0
  patch = tonumber(patch) or 0

  if major >= self.maxMajor then
    self.maxMajor = major
    self.store['x'] = store
    self.store['*'] = store
    self.store['x.x'] = store
    self.store['x.x.x'] = store
  end

  if minor >= (self.maxMinors[major] or 0) then
    self.maxMinors[major] = minor
    self.store[string.format('%d.x', major)] = store
    self.store[string.format('%d.x.x', major)] = store
  end

  if patch >= (self.maxPatches[string.format('%d.%d', major, minor)] or 0) then
    self.maxPatches[string.format('%d.%d', major, minor)] = patch
    self.store[string.format('%d.%d.x', major, minor)] = store
  end

  self.store[string.format('%d.%d.%d', major, minor, patch)] = store
  return self
end

function SemVerStore:get(version)
  return self.store[version]
end

return {
  name = "version",
  mustMatchWhenDerived = true,
  storage = SemVerStore,
  validate = function(value)
    assert(type(value) == "string", "Version should be a string")
  end
}
