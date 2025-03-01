module Animation.Decoders exposing (decoder)

import Animation.Types exposing (Anim(..), Bounce(..), CardDiscard(..), CardLimbo(..), Hurt(..), Transmute(..))
import Card.Decoders as Card
import Json.Decode as Json exposing (Decoder, fail, field, int, list, null, oneOf, string, succeed)
import Stack.Decoders as Stack
import WhichPlayer.Decoders as WhichPlayer


decoder : Decoder Anim
decoder =
    let
        animNameDecoder : Decoder String
        animNameDecoder =
            field "name" string

        getDecoder : String -> Decoder Anim
        getDecoder animName =
            case animName of
                "hurt" ->
                    hurtDecoder

                "heal" ->
                    healDecoder

                "draw" ->
                    drawDecoder

                "reflect" ->
                    reflectDecoder

                "reverse" ->
                    reverseDecoder

                "confound" ->
                    confoundDecoder

                "play" ->
                    playDecoder

                "transmute" ->
                    transmuteDecoder

                "mill" ->
                    millDecoder

                "gameEnd" ->
                    gameEndDecoder

                "rotate" ->
                    rotateDecoder

                "windup" ->
                    windupDecoder

                "fabricate" ->
                    fabricateDecoder

                "bounce" ->
                    bounceDecoder

                "discard" ->
                    discardDecoder

                "pass" ->
                    passDecoder

                "limbo" ->
                    limboDecoder

                "unlimbo" ->
                    unlimboDecoder

                _ ->
                    Json.fail <| "Unknown anim name " ++ animName
    in
    oneOf
        [ animNameDecoder |> Json.andThen getDecoder
        , null NullAnim
        ]


constDecoder : String -> Decoder ()
constDecoder x =
    let
        decode : String -> Decoder ()
        decode s =
            if s == x then
                succeed ()

            else
                fail <| s ++ " does not match " ++ x
    in
    string |> Json.andThen decode


hurtDecoder : Decoder Anim
hurtDecoder =
    let
        getDecoder : String -> Decoder Hurt
        getDecoder s =
            case s of
                "slash" ->
                    succeed Slash

                "bite" ->
                    succeed Bite

                "curse" ->
                    succeed Curse

                _ ->
                    fail <| s ++ " is not a valid hurt type"
    in
    Json.map3 Hurt
        (field "player" WhichPlayer.decoder)
        (field "damage" int)
        (field "hurt" string |> Json.andThen getDecoder)


healDecoder : Decoder Anim
healDecoder =
    Json.map2 Heal
        (field "player" WhichPlayer.decoder)
        (field "heal" int)


drawDecoder : Decoder Anim
drawDecoder =
    Json.map Draw
        (field "player" WhichPlayer.decoder)


reflectDecoder : Decoder Anim
reflectDecoder =
    Json.map Reflect
        (field "player" WhichPlayer.decoder)


confoundDecoder : Decoder Anim
confoundDecoder =
    Json.map Confound
        (field "player" WhichPlayer.decoder)


reverseDecoder : Decoder Anim
reverseDecoder =
    Json.map Reverse
        (field "player" WhichPlayer.decoder)


playDecoder : Decoder Anim
playDecoder =
    Json.map3 Play
        (field "player" WhichPlayer.decoder)
        (field "card" Card.decoder)
        (field "index" int)


transmuteDecoder : Decoder Anim
transmuteDecoder =
    let
        getDecoder : String -> Decoder Transmute
        getDecoder s =
            case s of
                "transmuteCard" ->
                    succeed TransmuteCard

                "transmuteOwner" ->
                    succeed TransmuteOwner

                _ ->
                    fail <| s ++ " is not a valid transmute type"
    in
    Json.map4 Transmute
        (field "player" WhichPlayer.decoder)
        (field "cardA" Stack.stackCardDecoder)
        (field "cardB" Stack.stackCardDecoder)
        (field "transmute" string |> Json.andThen getDecoder)


millDecoder : Decoder Anim
millDecoder =
    Json.map2 Mill
        (field "player" WhichPlayer.decoder)
        (field "card" Card.decoder)


gameEndDecoder : Decoder Anim
gameEndDecoder =
    Json.map GameEnd
        (field "winner" <| Json.maybe WhichPlayer.decoder)


rotateDecoder : Decoder Anim
rotateDecoder =
    Json.map Rotate
        (field "player" WhichPlayer.decoder)


windupDecoder : Decoder Anim
windupDecoder =
    Json.map Windup
        (field "player" WhichPlayer.decoder)


fabricateDecoder : Decoder Anim
fabricateDecoder =
    Json.map Fabricate
        (field "stackCard" Stack.stackCardDecoder)


bounceDecoder : Decoder Anim
bounceDecoder =
    let
        noBounceDecoder : Decoder Bounce
        noBounceDecoder =
            Json.map NoBounce <| field "finalStackIndex" int

        bounceDiscardDecoder : Decoder Bounce
        bounceDiscardDecoder =
            Json.map (always BounceDiscard) <| constDecoder "bounceDiscard"

        bounceIndexDecoder : Decoder Bounce
        bounceIndexDecoder =
            Json.map2 BounceIndex
                (field "stackIndex" int)
                (field "handIndex" int)
    in
    Json.map Bounce <|
        field "bounce" <|
            list <|
                oneOf [ noBounceDecoder, bounceDiscardDecoder, bounceIndexDecoder ]


discardDecoder : Decoder Anim
discardDecoder =
    let
        noDiscardDecoder : Decoder CardDiscard
        noDiscardDecoder =
            Json.map NoDiscard <| field "finalStackIndex" int

        cardDiscardDecoder : Decoder CardDiscard
        cardDiscardDecoder =
            Json.map (always CardDiscard) <| constDecoder "discard"
    in
    Json.map Discard <|
        field "discard" <|
            list <|
                oneOf [ noDiscardDecoder, cardDiscardDecoder ]


passDecoder : Decoder Anim
passDecoder =
    Json.map Pass
        (field "player" WhichPlayer.decoder)


limboDecoder : Decoder Anim
limboDecoder =
    let
        noLimboDecoder : Decoder CardLimbo
        noLimboDecoder =
            Json.map NoLimbo <| field "finalStackIndex" int

        cardLimboDecoder : Decoder CardLimbo
        cardLimboDecoder =
            Json.map (always CardLimbo) <| constDecoder "limbo"
    in
    Json.map Limbo <|
        field "limbo" <|
            list <|
                oneOf [ noLimboDecoder, cardLimboDecoder ]


unlimboDecoder : Decoder Anim
unlimboDecoder =
    Json.map Unlimbo
        (field "player" WhichPlayer.decoder)
