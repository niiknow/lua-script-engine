local jwt               = require "resty.jwt"
local validators        = require "resty.jwt-validators"
local cjson_safe        = require "cjson.safe"
local ngin              = require "sngin.ngin"
local _M = {}

_M.validators = validators

function _M.sign(payload, ttl, secret)
  local body = payload or {}
  body["iat"] = ngx.now()
  body["exp"] = body["iat"] + (ttl or 600)

  local jwt_token = jwt:sign(secret, {
    header = { typ = "JWT", alg = "HS256" },
    payload = body
  })

  return cjson_safe.encode({token = jwt_token})
end

function _M.auth(token, secret, claim_spec)
  if not token then
    ngx.log(ngx.WARN, err)
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end

  ngx.log(ngx.DEBUG, "Token: " .. token)

  if not claim_spec then
    claim_spec = {
      -- sub = validators.opt_matches("^[a-z]+$"),
      -- iss = validators.equals_any_of({ "local" }),
      exp = validators.opt_is_not_expired(),
      __jwt = validators.require_one_of({ "iat" }),
    }
  end

  local jwt_obj = jwt:verify(secret, token, claim_spec)
  if not jwt_obj.verified then
    ngx.log(ngx.WARN, "Invalid token: " .. jwt_obj.reason)
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson_safe.encode({ error = "invalid token", mesage = jwt_obj.reason }))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end

  ngx.log(ngx.DEBUG, "JWT: " .. cjson_safe.encode(jwt_obj))

  ngx.header["X-Auth-UserId"] = jwt_obj.payload.sub
end

return _M