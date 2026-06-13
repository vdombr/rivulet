module Rivulet
  module Routing
    Route = Struct.new(
      :http_method,
      :path,
      :callable,
      :scopes,
      :handler_name,
      :path_regex,
      :param_names,
      keyword_init: true
    )
  end
end
