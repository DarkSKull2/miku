{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}


module Network.Miku.Engine where

import           Air.Data.Record.SimpleLabel       hiding (get)
import           Air.Env                           hiding (length, mod, take,
                                                    (-), (.))
import           Control.Lens                      hiding (use)
import           Control.Monad.Reader              hiding (join)
import           Control.Monad.State               hiding (join)
import           Data.ByteString.Char8             (ByteString)
import qualified Data.ByteString.Char8             as B
import qualified Data.Default                      as Default
import           Data.List
import           Data.Maybe
import           Hack2
import           Hack2.Contrib.Middleware.NotFound
import           Hack2.Contrib.Middleware.UserMime
import           Hack2.Contrib.Utils               hiding (get, put)
import           Network.Miku.Config
import           Network.Miku.Type
import           Network.Miku.Utils
import           Prelude                           ((.))
import qualified Prelude                           as P


miku :: MikuMonad -> Application
miku miku_monad = miku_middleware miku_monad (not_found dummy_app)

miku_middleware :: MikuMonad -> Middleware
miku_middleware miku_monad =

  let miku_state                      = execState miku_monad mempty
      mime_filter                     = user_mime - miku_state ^. mimes
      miku_middleware_stack           = use - miku_state ^. middlewares
      miku_router_middleware          = use - miku_state ^. router
      pre_installed_middleware_stack  = use - pre_installed_middlewares
  in

  use [pre_installed_middleware_stack, mime_filter, miku_middleware_stack, miku_router_middleware]


miku_router :: RequestMethod -> ByteString -> AppMonad -> Middleware
miku_router route_method route_string app_monad app = \env ->
  if request_method env == route_method
    then
      case env & path_info & parse_params route_string of
        Nothing -> app env
        Just (_, params) ->
          let miku_app = run_app_monad - local (put_namespace miku_captures params) app_monad
          in
          miku_app env

    else
      app env


  where

    run_app_monad :: AppMonad -> Application
    run_app_monad app_monad = \env -> runReaderT app_monad env & flip execStateT Default.def


parse_params :: ByteString -> ByteString -> Maybe (ByteString, [(ByteString, ByteString)])
parse_params "*" x = Just (x, [])
parse_params "" ""  = Just ("", [])
parse_params "" _   = Nothing
parse_params "/" "" = Nothing
parse_params "/" "/"  = Just ("/", [])

parse_params t s =

  let template_tokens = B.split '/' t
      url_tokens      = B.split '/' s

      _template_last_token_matches_everything         = (template_tokens & length) P.> 0 && (["*"] `isSuffixOf` template_tokens)
      _template_tokens_length_equals_url_token_length = (template_tokens & length) == (url_tokens & length)
  in

  if not - _template_last_token_matches_everything || _template_tokens_length_equals_url_token_length
    then Nothing
    else
      let rs = zipWith capture template_tokens url_tokens
      in
      if all isJust rs
        then
          let token_length = length template_tokens
              location     = B.pack - "/" / (B.unpack - B.intercalate "/" - take token_length url_tokens)
          in
          Just - (location, rs & catMaybes & catMaybes)
        else Nothing

  where
    capture x y
      | ":" `isPrefixOf` B.unpack x = Just - Just (B.tail x, y)
      | x == "*" = Just Nothing
      | x == y = Just Nothing
      | otherwise = Nothing
