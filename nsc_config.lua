--
-- config
--
-- @copyright Copyright 2016 ZhangYue Inc. All rights reserved.
-- @license [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
-- @author wanglichao
-- @module nsc_lua.nsc_config
--


local NSC_CONFIG = {
    -- name service config
    name_service = {
        zk_path_tpl = "/arch_group/test/%s",
        lrucache_timeout = 60,  -- 60s
        lrucache_size = 200,  -- lrucache size
    },
}

return NSC_CONFIG
