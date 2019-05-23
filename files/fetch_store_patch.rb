module ActionDispatch
  class Request
    class Session
      alias_method :fetch, :[]
      alias_method :store, :[]=
    end
  end
  
  class Cookies
    class CookieJar
      alias_method :fetch, :[]
      alias_method :store, :[]=
    end
  end
end
