module Discard where

import Data.Aeson (ToJSON(..), (.=), object)

data CardDiscard = NoDiscard Int | CardDiscard
  deriving (Show, Eq)

instance ToJSON CardDiscard where
  toJSON (NoDiscard finalStackIndex) =
    object [
      "finalStackIndex" .= finalStackIndex
    ]
  toJSON CardDiscard = "discard"
