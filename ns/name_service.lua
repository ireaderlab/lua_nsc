--
-- name_service
--
-- @copyright Copyright 2016 ZhangYue Inc. All rights reserved.
-- @license [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
-- @author wanglichao
-- @module lua_nsc.ns.name_service
--

local qconf = require "qconf"
local cjson_safe = require "cjson.safe"
local cjson_decode = cjson_safe.decode

-- inner
local tools_cache_manager = require "tools.cache_manager"
local tools_lrucache_manager = require "tools.lrucache_manager"
local nsc_config = require "nsc_config"

local pairs = pairs
local pcall = pcall
local tonumber = tonumber
local string_find = string.find
local string_format = string.format

local ngx_log = ngx.log
local ngx_err = ngx.ERR
local ngx_debug = ngx.DEBUG

local NameService = {}

local function get_providers_with_config(namespace)
    local zk_path = string_format(nsc_config.name_service.zk_path_tpl, namespace)
    -- err=0 means ok
    err, val = qconf.get_batch_conf(zk_path)
    ngx_log(ngx_debug, "get_providers_with_config err=", err, ", namespace=", namespace, ", value len=", #val)
    if err ~= 0 then
        ngx_log(ngx_err, "get_providers_with_config failed, err=", err)
        return nil
    end
    return val
end

-- get config form qconf
-- @param[type=string] namespace
-- @param[type=table] strategy
--    example
--      {host = "192.168.6.7", backup={"192.168.56.101", "192.168.6.166"}}
function NameService.get_services(namespace, strategy)
    local providers = get_providers_with_config(namespace)
    if not providers then
        ngx_log(ngx_err, "get_services failed, please check qconf config, namespace=", namespace)
        return nil
    end
    local local_services, backup_services, services = {}, {}, {}
    local local_index, backup_index, index = 1, 1, 1
    for provider, config_str in pairs(providers) do
        local weight = 1
        if config_str ~= nil then
            local config = cjson_decode(config_str)
            if config then
                weight = tonumber(config.weight or 1)
            end
        end
        for i=1, weight do
            services[index] = provider
            index = index + 1
            if type(strategy) == "table" then
                local find_flag, _ =  string_find(provider, strategy.host)
                if find_flag ~= nil then
                    local_services[local_index] = provider
                    local_index = local_index + 1
                end
                if type(strategy.backup) == "table" then
                    for _, backup in pairs(strategy.backup) do
                        local find_backup_flag, _ =  string_find(provider, backup)
                        if find_backup_flag ~= nil then
                            backup_services[backup_index] = provider
                            backup_index = backup_index + 1
                        end
                    end
                end
            end
        end
    end
    -- local first
    if #local_services ~= 0 then
        ngx_log(ngx_debug, "use local_services len=", #local_services)
        return local_services
    end
    -- when no local then backup first
    if #backup_services ~= 0 then
        ngx_log(ngx_debug, "use backup_services len=", #backup_services)
        return backup_services
    end
    -- no local and no backup then all namespace's services are used
    if #services == 0 then
        ngx_log(ngx_err, "local_services and backup_services are empty for namespace=", namespace)
        return nil
    end
    ngx_log(ngx_debug, "use services len=", #services)
    return services
end

-- base on shared_cache
function NameService.get_services_by_shared_cache(namespace, strategy)
    local key = tools_cache_manager.namespace_key(namespace)
    return tools_cache_manager.get_or_set(key, function()
        return NameService.get_services(namespace, strategy)
    end)
end


-- base on lrucache
function NameService.get_services_by_lrucache(namespace, strategy)
    local key = tools_lrucache_manager.generate_key(namespace)
    ngx_log(ngx_debug, "get namespace_key=", key)
    return tools_lrucache_manager.get_or_set(key, function()
        return NameService.get_services(namespace, strategy)
    end)
end

return NameService
