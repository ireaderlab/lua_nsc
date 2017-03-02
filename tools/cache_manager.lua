--
-- ngx.shared.DICT
--
-- @copyright Copyright 2016 ZhangYue Inc. All rights reserved.
-- @license [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
-- @module nsc_lua.tools.cache_manager
--

local resty_lock = require "resty.lock"
local cjson = require "cjson"
local cache = ngx.shared.cache
local ngx_log = ngx.log

local CACHE_KEYS = {
    NAMESPACE = "namespace",
}

local _M = {}

function _M.rawset(key, value, exptime)
    return cache:set(key, value, exptime or 10)
end

function _M.set(key, value)
    if value then
        value = cjson.encode(value)
    end

    return _M.rawset(key, value)
end

function _M.rawget(key)
    return cache:get(key)
end

function _M.get(key)
    local value, flags = _M.rawget(key)
    if value then
        value = cjson.decode(value)
    end
    return value, flags
end

function _M.incr(key, value)
    return cache:incr(key, value)
end

function _M.delete(key)
    cache:delete(key)
end

function _M.delete_all()
    cache:flush_all() -- This does not free up the memory, only marks the items as expired
    cache:flush_expired() -- This does actually remove the elements from the memory
end


-- 生成cache的key
function _M.generate_key(namespace)
    return CACHE_KEYS.NAMESPACE..":"..namespace
end


function _M.get_or_set(key, cb)
    -- Try to get the value from the cache
    -- ngx.shared.DICT is shared by all nginx processes, so need lock it when set data
    -- 由于resty_lock是基于共享内存的非阻塞锁实现,因此不会阻塞进程,注意超时时间设置
    local value = _M.get(key)
    if value then return value end

    local lock, err = resty_lock:new("cache_locks", {
        exptime = 10,
        timeout = 0.5
    })
    if not lock then
        ngx_log(ngx.ERR, "could not create lock: ", err)
        return
    end

    -- The value is missing, acquire a lock
    local elapsed, err = lock:lock(key)
    if not elapsed then
        ngx_log(ngx.ERR, "failed to acquire cache lock: ", err)
    end

    -- Lock acquired. Since in the meantime another worker may have
    -- populated the value we have to check again
    value = _M.get(key)
    if not value then
        -- Get from closure
        value = cb()
        if value then
            local ok, err = _M.set(key, value)
            if not ok then
                ngx_log(ngx.ERR, err)
            end
        end
    end

    local ok, err = lock:unlock()
    if not ok and err then
        ngx_log(ngx.ERR, "failed to unlock: ", err)
    end

    return value
end

function _M.get_or_set_no_lock(key, cb)
    -- pid:{ngx.worker.pid()}:key
    local ngx_worker_pid = ngx.worker.pid()
    local cache_key = "pid:" .. ngx_worker_pid .. ":" .. key
    local value = _M.get(cache_key)
    if value then return value end
    value = cb()
    if value then
        local ok, err = _M.set(cache_key, value)
        if not ok then
            ngx_log(ngx.ERR, err)
        end
    end
    return value
end


return _M
