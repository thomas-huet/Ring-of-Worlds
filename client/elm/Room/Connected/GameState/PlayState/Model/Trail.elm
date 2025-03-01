module Trail exposing (view)

import Animation.State as Animation
import Animation.Types exposing (Anim(..), Bounce(..), HandBounce)
import Colour exposing (Colour)
import Ease
import Game.Types exposing (Context, Hover(..))
import Hand.Entities exposing (handCardPosition, playPosition)
import Math.Matrix4 exposing (makeLookAt, makeOrtho, makeRotate, makeScale3)
import Math.Vector2 exposing (Vec2, vec2)
import Math.Vector3 exposing (vec3)
import Render.Primitives
import Render.Shaders
import Stack.Entities
import Util exposing (interp2D)
import WebGL
import WhichPlayer.Types exposing (WhichPlayer(..))


toShaderSpace : Float -> Float -> Vec2 -> Vec2
toShaderSpace w h screenSpace =
    let
        { x, y } =
            Math.Vector2.toRecord screenSpace
    in
    vec2 (x / w) (1 - y / h)


trailQuad : Colour -> Vec2 -> Vec2 -> Context -> WebGL.Entity
trailQuad colour initial final { w, h, progress, anim, tick } =
    let
        start : Vec2
        start =
            interp2D trailProgress initial final

        end : Vec2
        end =
            interp2D progress start final

        trailProgress : Float
        trailProgress =
            Ease.inBounce (tick / Animation.animMaxTick anim)
    in
    Render.Primitives.quad Render.Shaders.trail
        { rotation = makeRotate pi (vec3 0 0 1)
        , scale = makeScale3 (0.5 * w) (0.5 * h) 1
        , color = colour
        , pos = vec3 (w * 0.5) (h * 0.5) 0
        , worldRot = makeRotate 0 (vec3 0 0 1)
        , perspective = makeOrtho 0 (w / 2) (h / 2) 0 0.01 1000
        , camera = makeLookAt (vec3 0 0 1) (vec3 0 0 0) (vec3 0 1 0)
        , start = toShaderSpace w h start
        , end = toShaderSpace w h end
        }


view : Context -> List WebGL.Entity
view ({ anim, model, w, h } as ctx) =
    case anim of
        Play PlayerA _ i ->
            let
                n : Int
                n =
                    List.length model.hand + 1

                initial : Vec2
                initial =
                    handCardPosition ctx PlayerA i n NoHover

                final : Vec2
                final =
                    playPosition ctx

                colour : Colour
                colour =
                    Colour.card PlayerA
            in
            [ trailQuad colour initial final ctx ]

        Play PlayerB _ i ->
            let
                n : Int
                n =
                    model.otherHand + 1

                initial : Vec2
                initial =
                    handCardPosition ctx PlayerB i n NoHover

                final : Vec2
                final =
                    playPosition ctx

                colour : Colour
                colour =
                    Colour.card PlayerB
            in
            [ trailQuad colour initial final ctx ]

        Draw PlayerA ->
            let
                n : Int
                n =
                    List.length model.hand

                initial : Vec2
                initial =
                    vec2 w h

                final : Vec2
                final =
                    handCardPosition ctx PlayerA n (n + 1) NoHover

                colour : Colour
                colour =
                    Colour.card PlayerA
            in
            [ trailQuad colour initial final ctx ]

        Draw PlayerB ->
            let
                n : Int
                n =
                    model.otherHand

                initial : Vec2
                initial =
                    vec2 w 0

                final : Vec2
                final =
                    handCardPosition ctx PlayerB n (n + 1) NoHover

                colour : Colour
                colour =
                    Colour.card PlayerB
            in
            [ trailQuad colour initial final ctx ]

        Bounce bounces ->
            let
                paBounces : List HandBounce
                paBounces =
                    Animation.getPlayerBounceCards PlayerA bounces model.stack

                pbBounces : List HandBounce
                pbBounces =
                    Animation.getPlayerBounceCards PlayerB bounces model.stack

                na =
                    List.length model.hand + List.length paBounces

                nb =
                    model.otherHand + List.length pbBounces

                makeTrail : WhichPlayer -> HandBounce -> WebGL.Entity
                makeTrail which { stackIndex, handIndex } =
                    let
                        n =
                            case which of
                                PlayerA ->
                                    na

                                PlayerB ->
                                    nb

                        colour =
                            Colour.card which

                        stackEntity =
                            Stack.Entities.stackEntity ctx 0 (List.length model.stack) stackIndex

                        initial =
                            stackEntity.position

                        final =
                            handCardPosition ctx which handIndex n NoHover
                    in
                    trailQuad colour initial final ctx
            in
            List.map (makeTrail PlayerA) paBounces
                ++ List.map (makeTrail PlayerB) pbBounces

        _ ->
            []
