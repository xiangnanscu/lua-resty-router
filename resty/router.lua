-- router perform plain or regex match
local match = ngx.re.match

local version = '1.0'
-- http://www.tutorialspoint.com/http/http_methods.htm
local HTTP_METHODS = {
    GET=true, 
    POST=true, 
    HEAD=true, 
    PATCH=true,
    DELETE=true, 
    OPTIONS=true, 
    PUT=true,
    CONNECT=true, 
    TRACE=true,
}
local function check_method(method)
    assert(HTTP_METHODS[method:upper()], 'invalid http method: '..method)
end

local function require_http_methods(valid_methods)
    local function decorator(controller)
        local function f(request)
            if not valid_methods[request.get_method()] then
                return nil, 'method not allowed', 405
            else
                return controller(request)
            end
        end
        return f     
    end
    return decorator
end

local function callable(f)
    return type(f) == 'function' or (
        type(f) == 'table' 
        and getmetatable(f) 
        and callable(getmetatable(f).__call))
end

local function clean_methods(methods)  
    if not methods then
        return
    end
    if type(methods) == 'string' then
        methods = {methods:upper()}
    end
    local ret = {}
    for i, method in ipairs(methods) do
        check_method(method)
        ret[method:upper()] = true
    end
    return ret
end

local Router = {}
Router.__index = Router
Router.__call = function (t, path)
    local function f(controller)
        if callable(controller) then
            t:add{path, controller}
        else
            assert(type(controller) == 'table', 'a controller should be a function or table')
            for method, sub_controller in pairs(controller) do
                check_method(method)
                t:add{path, sub_controller, method}
            end
        end
    end
    return f
end
function Router.new(cls, self)
    self = setmetatable(self or {}, cls)
    self.hashlookup = {}
    self.arraylookup = {}
    for i, pattern in ipairs(self) do
        self:add(pattern)
    end
    return self
end
function Router.get(self, path)
    local function f(controller)
        self:add{path, controller, 'get'}
    end
    return f
end
function Router.post(self, path)
    local function f(controller)
        self:add{path, controller, 'post'}
    end
    return f
end
function Router.clean_urlpattern(self, urlpat)
    local path = urlpat.path or urlpat[1]
    local controller = urlpat.controller or urlpat[2]
    local methods = urlpat.methods or urlpat[3]
    assert(path and controller, 'path and controller must be provided for a url pattern.')
    assert(methods == nil or type(methods) == 'table' or type(methods) == 'string', 'methods must be nil or table or string')
    assert(type(path) == 'string', 'path must be a string for a url pattern.')
    assert(callable(controller), 'controller must be a callable object for a url pattern.')  
    return path, controller, clean_methods(methods)
end
function Router.add(self, urlpat)
    local path, controller, methods = self:clean_urlpattern(urlpat)
    if methods then
        controller = require_http_methods(methods)(controller)
    end
    if path:sub(1, 1) == '~' then 
        table.insert(self.arraylookup, {path:sub(2), controller})
    else
        self.hashlookup[path] = controller
    end
    return self
end
function Router.match(self, uri)
    -- first perform plain match (a hash lookup)
    local controller = self.hashlookup[uri]
    if controller then
        return controller
    end
    -- then perform regex match
    for i, urlpat in ipairs(self.arraylookup) do
        local captured, err = match(uri, urlpat[1], 'josu')
        if err then
            return nil, 'error when matching uri:'..tostring(err), 500
        end
        if captured then
            return urlpat[2], captured
        end
    end
    return nil, 'page not found', 404
end
function Router.exec(self)
    local uri = ngx.var.document_uri
    local controller, captured, exit_number = self:match(uri)
    if not controller then
        return nil, captured, exit_number
    end
    local request = setmetatable({kwargs = captured, uri = uri}, {__index = ngx.req}) 
    return controller(request)
end

return Router