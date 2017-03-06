--
-- resty.lrucache wrap
--
-- @copyright Copyright 2017 ZhangYue Inc. All rights reserved.
-- @license [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
-- @module lua_nsc.tools.lrucache_manager
--

local _M = {}

local cjson_safe = require "cjson.safe"
local lrucache = require "resty.lrucache"
local nsc_config = require "nsc_config"

local ngx_log = ngx.log
local ngx_err = ngx.ERR
local ngx_debug = ngx.DEBUG
local lrucache_size = nsc_config.name_service.lrucache_size
local lrucache_timeout = nsc_config.name_service.lrucache_timeout


local lru_cache, err = lrucache.new(lrucache_size)  -- allow up to 200 items in the cache
if not lru_cache then
    return ngx_log(ngx_err, "failed to create the cache: " .. (err or "unknown"))
end


local CACHE_KEYS = {
    NAMESPACE = "lrucache",
}


function _M.generate_key(key)
    return CACHE_KEYS.NAMESPACE..":"..key
end

function _M.get_or_set(key, cb)
    local value = lru_cache:get(key)
    if value then
        ngx_log(ngx_debug, "use lrucache get hit value=", cjson_safe.encode(value))
        return value
    end
    value = cb()
    if value then
        ngx_log(ngx_debug, "use lrucache get miss key=", key)
        lru_cache:set(key, value, lrucache_timeout)
    end
    return value
end

return _M
