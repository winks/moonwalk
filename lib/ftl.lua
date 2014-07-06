local ftl = {}

local mw = require 'lib.mw'

function ftl.user(self, user)
  fn = self:html(function()
    h1(user.display_name)
    return a({ href = user.url }, user.url)
  end)

  return { layout = 'my_layout', fn }

end

return ftl
