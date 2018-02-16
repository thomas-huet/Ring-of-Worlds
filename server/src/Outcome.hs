module Outcome where

import Data.Aeson (ToJSON(..), (.=), object)
import Data.Text (Text)

import GameState (PlayState)
import Model (CardAnim, Model, StackCard)
import ModelDiff (ModelDiff)
import Player (WhichPlayer)
import Username (Username)


type ExcludePlayer = WhichPlayer


data Outcome =
    Sync
  | Encodable Encodable
  deriving (Eq, Show)


data Encodable =
    Chat Username Text
  | Hover ExcludePlayer (Maybe Int)
  | Resolve [(ModelDiff, Maybe CardAnim, Maybe StackCard)] Model PlayState
  deriving (Eq, Show)


instance ToJSON Encodable where
  toJSON (Chat name msg) =
    object [
      "name" .= name
    , "msg"  .= msg
    ]
  toJSON (Hover _ index) =
    toJSON index
  toJSON (Resolve res initial state) =
    object [
      "list"    .= res
    , "initial" .= initial
    , "final"   .= state
    ]
