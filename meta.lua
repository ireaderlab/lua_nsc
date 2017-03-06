--
-- nsc meta
--
-- @copyright Copyright 2016 ZhangYue Inc. All rights reserved.
-- @license [Apache 2.0](https://opensource.org/licenses/Apache-2.0)
-- @author wanglichao
-- @module zynsc_lua.zynsc
-- @version v0.3.1
--

local version = setmetatable({
  major = 0,
  minor = 1,
  patch = 0,
  pre_release = nil
}, {
  __tostring = function(t)
    return string.format("%d.%d.%d%s", t.major, t.minor, t.patch,
                         t.pre_release and t.pre_release or "")
  end
})

return {
  _NAME = "nsc",
  _VERSION = tostring(version),
  _VERSION_TABLE = version,

  -- third-party dependencies' required version, as they would be specified
  -- to lua-version's `set()` in the form {from, to}
  _DEPENDENCIES = {
    tengine = {"2.1.2"},
    nginx = {"1.6.2"},
    --resty = {}, -- not version dependent for now
  }
}
