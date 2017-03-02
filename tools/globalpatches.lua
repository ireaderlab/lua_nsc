--
-- zynsc patch 模块
--
-- @copyright Copyright 2016 ZhangYue Inc. All rights reserved.
-- @license [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
-- @module zynsc_lua.tools.globalpatches
-- @version v0.1.2
--

local meta = require "meta"
local randomseed = math.randomseed

_G._ZYNSC = {
  _NAME = meta._NAME,
  _VERSION = meta._VERSION
}

local seed


-- 将全局math的seed方法进行patch统一使用time+workerpid方式
_G.math.randomseed = function()
  if not seed then
    if ngx.get_phase() ~= "init_worker" then
      error("math.randomseed() must be called in init_worker", 2)
    end

    seed = ngx.time() + ngx.worker.pid()
    ngx.log(ngx.DEBUG, "random seed: ", seed, " for worker n", ngx.worker.id(),
                       " (pid: ", ngx.worker.pid(), ")")
    randomseed(seed)
  else
    ngx.log(ngx.DEBUG, "attempt to seed random number generator, but ",
                       "already seeded with ", seed)
  end

  return seed
end
