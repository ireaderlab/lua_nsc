--
-- a set of utils function
--
-- @copyright Copyright 2016 ZhangYue Inc. All rights reserved.
-- @license [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
-- @module zynsc_lua.tools.utils
--


_M = {}

local random = math.random

function _M.random_choice(source_list)
    return source_list[random(#source_list)]
end

return _M
