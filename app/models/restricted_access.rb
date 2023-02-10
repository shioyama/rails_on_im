module RestrictedAccess
  def self.allow?(request)
    request.local?
  end

  class RouteConstraint
    def matches?(request)
      RestrictedAccess.allow?(request)
    end
  end
end
