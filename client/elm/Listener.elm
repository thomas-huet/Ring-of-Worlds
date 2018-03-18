module Listener exposing (..)

import Animation.Types exposing (Anim(..))
import Audio exposing (SoundOption(..), playSound, playSoundWith)
import GameState.State as GameState exposing (resolvable)
import GameState.Types exposing (GameState(..))
import Main.Messages exposing (Msg)
import Resolvable.State exposing (activeAnim, tickStart)
import Resolvable.Types as Resolvable
import WhichPlayer.Types exposing (WhichPlayer(..))


listen : Float -> GameState -> Cmd Msg
listen time state =
    let
        modelListen : Resolvable.Model -> Cmd Msg
        modelListen res =
            if tickStart res then
                let
                    sfxURL : Maybe String
                    sfxURL =
                        activeAnim res |> Maybe.andThen animSfx

                    volume : Float
                    volume =
                        0.5
                in
                    case sfxURL of
                        Just url ->
                            playSoundWith
                                ("/sfx/" ++ url)
                                [ Volume volume ]

                        Nothing ->
                            Cmd.none
            else
                Cmd.none
    in
        case state of
            Selecting _ ->
                playSoundWith "/music/slowsadjazz.mp3" [ Loop, Once ]

            Started started ->
                modelListen <| resolvable started

            otherwise ->
                Cmd.none


animSfx : Anim -> Maybe String
animSfx anim =
    case anim of
        Slash _ d ->
            case d of
                0 ->
                    Nothing

                otherwise ->
                    Just "damage.mp3"

        Heal _ ->
            Just "heal.mp3"

        Draw _ ->
            Just "draw.wav"

        Bite _ d ->
            Just "bite.wav"

        Reverse _ ->
            Just "reverse.mp3"

        Play _ _ ->
            Just "playCard.wav"

        Transmute _ _ _ ->
            Just "transmute.mp3"

        Obliterate _ ->
            Just "obliterate.mp3"

        GameEnd winner ->
            case winner of
                Just PlayerA ->
                    Just "victory.wav"

                Just PlayerB ->
                    Just "defeat.mp3"

                Nothing ->
                    Just "draw.wav"

        Adhoc _ _ sfx ->
            Just sfx

        otherwise ->
            Nothing
