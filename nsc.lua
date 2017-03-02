--
-- nsc
--
-- @copyright Copyright 2016 ZhangYue Inc. All rights reserved.
-- @license [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
-- @author wanglichao
-- @module lua_nsc.nsc
-- @version v0.3.1
--

-- patch must be first
require("tools.globalpatches")

-- third
local pl_stringx = require("pl.stringx")
local cjson_safe = require("cjson.safe")

-- nginx
local ngx_upstream = require("ngx.upstream")
local ngx_balancer = require("ngx.balancer")

-- inner
local name_service = require("ns.name_service")
local tools_utils = require("tools.utils")
local redis_api = require("redis.redis_api")
local nsc_config = require("nsc_config")

local tonumber = tonumber
local ipairs = ipairs
local string_gsub = string.gsub

local ngx_get_upstream_servers = ngx_upstream.get_servers
local ngx_log = ngx.log
local ngx_err = ngx.ERR
local ngx_debug = ngx.DEBUG

local random_choice = tools_utils.random_choice


local NSClient = {}

-- global init
function NSClient.init()
end

-- worker init
function NSClient.init_worker()
    math.randomseed()
end


-- get upstream servers when get from qconf failed
local function get_upstream(namespace)
    local services = {}
    local servers, err = ngx_get_upstream_servers(namespace)
    if err ~= nil or not servers then
        ngx_log(ngx_err, "failed to get servers in upstream ", namespace)
        return nil
    end
    local index = 1
    for _, srv in ipairs(servers) do
        local addr = srv.addr
        local backup = srv.backup
        if addr and not backup then
            local weight = tonumber(srv.weight or 1)
            for i=1, weight do
                services[index] = addr
                index = index + 1
            end
        end
    end
    return services
end


local function get_random_service(namespace, strategy)
    local services = name_service.get_services_by_lrucache(namespace, strategy)
    if services == nil then
        -- get from nginx conf when qconf failed to get_conf
        services = get_upstream(namespace)
    end
    ngx_log(ngx_debug, "nsc.get_random_service, services length=", #services)
    return random_choice(services)
end


-- @param[type=string] namespace
function NSClient.get_service(namespace, strategy)
    local service = get_random_service(namespace, strategy)
    if service ~= nil then
        service, _ = string_gsub(service, "_", ":")
        return service
    end
    if not service then
        ngx_log(ngx_err, "nsc.get_service failed, namespace=", namespace)
        return ngx.exit(500)
    end
end


function NSClient.use_upstream(namespace, strategy)
    ngx.var.upstream_url = NSClient.get_service(namespace, strategy)
end

function NSClient.balance(namespace, strategy)
    local service = get_random_service(namespace, strategy)
    ngx_log(ngx_debug, "nsc.balance get_random_service=", service)
    if service ~= nil then
        local host_port = pl_stringx.split(service, "_")
        if host_port ~= nil then
            local host, port = host_port[1], host_port[2]
            local ok, err = ngx_balancer.set_current_peer(host, port)
            if not ok then
                ngx_log(ngx_err, "nsc failed to set current peer, err=", err)
                return ngx.exit(500)
            end
        else
            ngx_log(ngx_err, "nsc.balance failed to get service, namespace=", namespace)
            return ngx.exit(500)
        end
    end
end


-- http protocol to redis protocol
function NSClient.get_data_from_redis(namespace)
    local redis_config = nsc_config.redis
    local service = get_random_service(namespace)
    if service ~= nil then
        local ip_port = pl_stringx.split(service, "_")
        if ip_port ~= nil then
            redis_config.ip = ip_port[1]
            redis_config.port = ip_port[2]
        end
    else
        ngx_log(ngx_err, "get_random_service failed, namespace: ", namespace)
    end
    -- get data from redis
    redis_api.get_data_from_redis(redis_config)
end

-- example: namespace = {"cps.test.http", "uc.test.http"} or namespace = "cps.test.http"
function NSClient.get_servers(namespace, strategy)
    local result = {}
    if type(namespace) == "string" then
        namespace = {namespace}
    end
    for _, ns in pairs(namespace) do
        local services = name_service.get_services_by_lrucache(ns, strategy)
        if services == nil then
            services = get_upstream(ns)
        end
        result[ns] = services
        ngx_log(ngx_debug, "get_servers services=", cjson_safe.encode(services))
    end
    ngx.say(cjson_safe.encode(result))
end

return NSClient
