{-# OPTIONS_GHC -Wno-missing-local-signatures #-}

module Restyler.Restyler
    ( Restyler(..)
    , getAllRestylersVersioned

    -- * Exported for testing
    , upgradeEnabled
    )
where

import Restyler.Prelude

import Data.Aeson
import Data.Aeson.Casing
import qualified Data.HashMap.Lazy as HM
import Data.Yaml (decodeFileThrow)
import Restyler.App.Class
import Restyler.Config.Include
import Restyler.Config.Interpreter
import Restyler.Delimited
import Restyler.RemoteFile

data Restyler = Restyler
    { rEnabled :: Bool
    , rName :: String
    , rImage :: String
    , rCommand :: [String]
    , rArguments :: [String]
    , rInclude :: [Include]
    , rInterpreters :: [Interpreter]
    , rDelimiters :: Maybe Delimiters
    , rSupportsArgSep :: Bool
    , rSupportsMultiplePaths :: Bool
    , rDocumentation :: [String]
    }
    deriving stock (Eq, Show, Generic)

instance FromJSON Restyler where
    parseJSON = genericParseJSON (aesonPrefix snakeCase) . upgradeEnabled

-- | Upgrade values from @restylers.yaml@ that lack an @enabled@ key
--
-- Hard-code a value from the list based on the default configuration present
-- here before such a key existed.
--
upgradeEnabled :: Value -> Value
upgradeEnabled =
    overObject $ override "enabled" $ Bool . maybe True enabled . HM.lookup
        "name"
  where
    overObject f = \case
        Object o -> Object $ f o
        v -> v
    override k f o = insertIfMissing k (f o) o
    enabled = (`notElem` disabledRestylers)
    disabledRestylers =
        ["brittany", "google-java-format", "hindent", "hlint", "jdt"]

instance ToJSON Restyler where
    toJSON = genericToJSON $ aesonPrefix snakeCase
    toEncoding = genericToEncoding $ aesonPrefix snakeCase

getAllRestylersVersioned
    :: (HasLogFunc env, HasDownloadFile env) => String -> RIO env [Restyler]
getAllRestylersVersioned version = do
    downloadRemoteFile restylers
    decodeFileThrow $ rfPath restylers
  where
    restylers = RemoteFile
        { rfUrl = URL $ pack $ restylersYamlUrl version
        , rfPath = "/tmp/restylers-" <> version <> ".yaml"
        }

restylersYamlUrl :: String -> String
restylersYamlUrl version =
    "https://docs.restyled.io/data-files/restylers/manifests/"
        <> version
        <> "/restylers.yaml"
