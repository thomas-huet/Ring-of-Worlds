{-# LANGUAGE FlexibleContexts, FlexibleInstances #-}

module DSL.Beta.Interpreters where

import Bounce (CardBounce(..))
import Card (Card)
import CardAnim (Transmute(..), cardAnimDamage)
import Control.Monad (when)
import Control.Monad.Free (Free(..), foldFree, liftF)
import Data.Functor.Sum (Sum(..))
import Data.Maybe (fromMaybe)
import Data.Monoid ((<>))
import Discard (CardDiscard(..))
import DSL.Beta.DSL
import DSL.Util (toLeft, toRight)
import Limbo (CardLimbo(..))
import Player (WhichPlayer(..))

import Life (Life)
import Model (Model, gameover, maxHandLength)
import ModelDiff (ModelDiff)
import ResolveData (ResolveData(..))
import Safe (headMay)
import StackCard (StackCard(..), changeOwner)

import qualified DSL.Alpha as Alpha
import qualified DSL.Anim as Anim
import qualified DSL.Log as Log
import qualified ModelDiff

import {-# SOURCE #-} Cards (theEnd)


alphaI :: Program a -> Alpha.Program a
alphaI (Free (Raw p n))          = p                             >>  alphaI n
alphaI (Free (Hurt d w _ n))     = Alpha.hurt d w                >>  alphaI n
alphaI (Free (Heal h w n))       = Alpha.heal h w                >>  alphaI n
alphaI (Free (Draw w d n))       = Alpha.draw w d                >>  alphaI n
alphaI (Free (AddToHand w c n))  = Alpha.addToHand w c           >>  alphaI n
alphaI (Free (Reflect n))        = Alpha.modStackAll changeOwner >>  alphaI n
alphaI (Free (Confound n))       = Alpha.confound                >>  alphaI n
alphaI (Free (Reverse n))        = Alpha.modStack reverse        >>  alphaI n
alphaI (Free (Play w c i n))     = Alpha.play w c i              >>  alphaI n
alphaI (Free (Transmute c _ n))  = Alpha.transmute c             >>  alphaI n
alphaI (Free (Rotate n))         = Alpha.rotate                  >>  alphaI n
alphaI (Free (Windup n))         = Alpha.windup                  >>  alphaI n
alphaI (Free (Fabricate c n))    = Alpha.modStack ((:) c)        >>  alphaI n
alphaI (Free (Bounce f n))       = Alpha.bounce f                >>  alphaI n
alphaI (Free (Discard f n))      = Alpha.discard f               >>  alphaI n
alphaI (Free (SetHeadOwner w n)) = Alpha.setHeadOwner w          >>  alphaI n
alphaI (Free (Limbo f n))        = Alpha.limbo f                 >>  alphaI n
alphaI (Free (Unlimbo n))        = Alpha.unlimbo                 >>  alphaI n
alphaI (Free (GetGen f))         = Alpha.getGen                  >>= alphaI . f
alphaI (Free (GetRot f))         = Alpha.getRot                  >>= alphaI . f
alphaI (Free (GetLife w f))      = Alpha.getLife w               >>= alphaI . f
alphaI (Free (GetHand w f))      = Alpha.getHand w               >>= alphaI . f
alphaI (Free (GetDeck w f))      = Alpha.getDeck w               >>= alphaI . f
alphaI (Free (GetStack f))       = Alpha.getStack                >>= alphaI . f
alphaI (Free (GetLimbo f))       = Alpha.getLimbo                >>= alphaI . f
alphaI (Free (RawAnim _ n))      = alphaI n
alphaI (Free (Null n))           = alphaI n
alphaI (Pure x)                  = Pure x


basicAnim :: Anim.DSL () -> Alpha.Program a -> AlphaAnimProgram a
basicAnim anim alphaProgram = toLeft alphaProgram <* (toRight . liftF $ anim)


animI :: DSL a -> (Alpha.Program a -> AlphaAnimProgram a)
animI (Null _)           = basicAnim $ Anim.Null ()
animI (Hurt d w h _)     = basicAnim $ Anim.Hurt w d h ()
animI (Reflect _)        = basicAnim $ Anim.Reflect ()
animI (Confound _)       = basicAnim $ Anim.Confound ()
animI (Reverse _)        = basicAnim $ Anim.Reverse ()
animI (Rotate _)         = basicAnim $ Anim.Rotate ()
animI (Windup _)         = basicAnim $ Anim.Windup ()
animI (Fabricate c _)    = basicAnim $ Anim.Fabricate c ()
animI (RawAnim r _)      = basicAnim $ Anim.Raw r ()
animI (Heal _ w _)       = healAnim w
animI (AddToHand w c  _) = addToHandAnim w c
animI (Draw w d _)       = drawAnim w d
animI (Play w c i _)     = playAnim w c i
animI (Transmute c t _)  = transmuteAnim c t
animI (Bounce f _)       = bounceAnim f
animI (Discard f _)      = discardAnim f
animI (SetHeadOwner w _) = setHeadOwnerAnim w
animI (Limbo f _)        = limboAnim f
animI (Unlimbo _)      = unlimboAnim
animI _                  = toLeft


healAnim :: WhichPlayer -> Alpha.Program a -> AlphaAnimProgram a
healAnim w alpha = do
  oldLife <- toLeft $ Alpha.getLife w
  final <- toLeft alpha
  newLife <- toLeft $ Alpha.getLife w
  let lifeChange = newLife - oldLife
  toRight . liftF $ Anim.Heal w lifeChange ()
  return final


drawAnim :: WhichPlayer -> WhichPlayer -> Alpha.Program a -> AlphaAnimProgram a
drawAnim w d alpha = do
  nextCard <- headMay <$> toLeft (Alpha.getDeck d)
  handLength <- length <$> toLeft (Alpha.getHand w)
  final <- toLeft alpha
  if (handLength < maxHandLength)
    then toRight . liftF $ Anim.Draw w ()
    else toRight . liftF $ Anim.Mill w (fromMaybe theEnd nextCard) ()
  return final


addToHandAnim :: WhichPlayer -> Card -> Alpha.Program a -> AlphaAnimProgram a
addToHandAnim w c alpha = do
  handLength <- length <$> toLeft (Alpha.getHand w)
  final <- toLeft alpha
  if (handLength < maxHandLength)
    then toRight . liftF $ Anim.Draw w ()
    else toRight . liftF $ Anim.Mill w c ()
  return final


playAnim :: WhichPlayer -> Card -> Int -> Alpha.Program a -> AlphaAnimProgram a
playAnim w c i alpha = do
  final <- toLeft alpha
  toRight . liftF $ Anim.Play w c i ()
  return final


transmuteAnim :: Card -> Transmute -> Alpha.Program a -> AlphaAnimProgram a
transmuteAnim cb t alpha = do
  stackHead <- headMay <$> toLeft Alpha.getStack
  final <- toLeft alpha
  case stackHead of
    (Just ca) ->
      let o = stackcard_owner ca in
      toRight . liftF $ Anim.Transmute ca (StackCard o cb) t ()
    Nothing ->
      toRight . liftF $ Anim.Null ()
  return final


bounceAnim :: (StackCard -> Bool) -> Alpha.Program a -> AlphaAnimProgram a
bounceAnim f alpha = do
  bounces <- toLeft $ getBounces f
  toRight . liftF $ Anim.Bounce bounces ()
  final <- toLeft alpha
  toRight . liftF $ Anim.Null ()
  return final


getBounces :: (StackCard -> Bool) -> Alpha.Program [CardBounce]
getBounces f = do
  stack <- Alpha.getStack
  handALen <- length <$> Alpha.getHand PlayerA
  handBLen <- length <$> Alpha.getHand PlayerB
  return $ getBounces' 0 0 handALen handBLen $ zip stack (f <$> stack)
  where
    getBounces' :: Int -> Int -> Int -> Int -> [(StackCard, Bool)] -> [CardBounce]
    getBounces' stackIndex finalStackIndex handAIndex handBIndex ((StackCard owner _, doBounce):rest) =
      if doBounce then
        case owner of
          PlayerA ->
            if handAIndex >= maxHandLength then
              BounceDiscard :
                getBounces' (stackIndex + 1) finalStackIndex handAIndex handBIndex rest
            else
              BounceIndex stackIndex handAIndex :
                getBounces' (stackIndex + 1) finalStackIndex (handAIndex + 1) handBIndex rest
          PlayerB ->
            if handBIndex >= maxHandLength then
              BounceDiscard :
                getBounces' (stackIndex + 1) finalStackIndex handAIndex handBIndex rest
            else
              BounceIndex stackIndex handBIndex :
                getBounces' (stackIndex + 1) finalStackIndex handAIndex (handBIndex + 1) rest
      else
        NoBounce finalStackIndex :
          getBounces' (stackIndex + 1) (finalStackIndex + 1) handAIndex handBIndex rest
    getBounces' _ _ _ _ [] = []


discardAnim :: ((Int, StackCard) -> Bool) -> Alpha.Program a -> AlphaAnimProgram a
discardAnim f alpha = do
  discards <- toLeft $ getDiscards f
  toRight . liftF $ Anim.Discard discards ()
  final <- toLeft alpha
  toRight . liftF $ Anim.Null ()
  return final


limboAnim :: ((Int, StackCard) -> Bool) -> Alpha.Program a -> AlphaAnimProgram a
limboAnim f alpha = do
  limbos <- toLeft $ getLimbos f
  toRight . liftF $ Anim.Limbo limbos ()
  final <- toLeft alpha
  toRight . liftF $ Anim.Null ()
  return final


unlimboAnim :: Alpha.Program a -> AlphaAnimProgram a
unlimboAnim alpha = do
  l <- toLeft $ Alpha.getLimbo
  final <- toLeft alpha
  when (not . null $ l) $
    toRight . liftF $ Anim.Unlimbo ()
  return final


-- Merge with getLimbos / getBounces?
getDiscards :: ((Int, StackCard) -> Bool) -> Alpha.Program [CardDiscard]
getDiscards f = do
  stack <- Alpha.getStack
  return $ getDiscards' 0 0 $ f <$> zip [0..] stack
    where
      getDiscards' :: Int -> Int -> [Bool] -> [CardDiscard]
      getDiscards' stackIndex finalStackIndex (doDiscard:rest) =
        if doDiscard then
          CardDiscard : getDiscards' (stackIndex + 1) finalStackIndex rest
        else
          NoDiscard finalStackIndex : getDiscards' (stackIndex + 1) (finalStackIndex + 1) rest
      getDiscards' _ _ [] = []


getLimbos :: ((Int, StackCard) -> Bool) -> Alpha.Program [CardLimbo]
getLimbos f = do
  stack <- Alpha.getStack
  return $ getLimbos' 0 0 $ f <$> zip [0..] stack
    where
      getLimbos' :: Int -> Int -> [Bool] -> [CardLimbo]
      getLimbos' stackIndex finalStackIndex (doLimbo:rest) =
        if doLimbo then
          CardLimbo : getLimbos' (stackIndex + 1) finalStackIndex rest
        else
          NoLimbo finalStackIndex : getLimbos' (stackIndex + 1) (finalStackIndex + 1) rest
      getLimbos' _ _ [] = []


setHeadOwnerAnim :: WhichPlayer -> Alpha.Program a -> AlphaAnimProgram a
setHeadOwnerAnim w alpha = do
  stackHead <- headMay <$> toLeft Alpha.getStack
  final <- toLeft alpha
  case stackHead of
    Just (StackCard o c) ->
      toRight . liftF $ Anim.Transmute (StackCard o c) (StackCard w c) TransmuteOwner ()
    Nothing ->
      toRight . liftF $ Anim.Null ()
  return final


type AlphaAnimProgram = Free (Sum Alpha.DSL Anim.DSL)
type AlphaLogAnimProgram = Free (Sum (Sum Alpha.DSL Log.DSL) Anim.DSL)


liftAlphaAnim :: ∀ a . Sum Alpha.DSL Anim.DSL a -> AlphaLogAnimProgram a
liftAlphaAnim (InL alpha) = toLeft $ Alpha.decorateLog alpha
liftAlphaAnim (InR anim)  = toRight $ liftF anim


betaI :: ∀ a . DSL a -> AlphaLogAnimProgram a
betaI x = (foldFree liftAlphaAnim) . (animI x) . alphaI $ liftF x


execute :: Model -> Maybe StackCard -> AlphaLogAnimProgram () -> (Model, String, [ResolveData])
execute = execute' "" [] mempty
  where
    execute' :: String -> [ResolveData] -> ModelDiff -> Model -> Maybe StackCard -> AlphaLogAnimProgram () -> (Model, String, [ResolveData])

    execute' l a _ m _ (Pure _) =
      (m, l, a)

    execute' l a d m s (Free (InR anim)) =
      let
        next = if gameover m then Pure () else Anim.next anim
        cardAnim = Anim.animate anim
        damage = fromMaybe (0, 0) $ cardAnimDamage <$> cardAnim
        resolveData = ResolveData d cardAnim damage s
      in
        execute' l (a ++ [resolveData]) mempty m s next

    execute' l a d m s (Free (InL (InL p))) =
      let
         (newDiff, n) = Alpha.alphaEffI m p
         newModel = ModelDiff.update m newDiff
      in
        execute' l a (d <> newDiff) newModel s n

    execute' l a d m s (Free (InL (InR (Log.Log l' n)))) =
      execute' (l ++ l' ++ "\n") a d m s n


damageNumbersI :: Model -> Program () -> (Life, Life)
damageNumbersI model program =
  let
    (_, _, resolveData) = execute model Nothing $ foldFree betaI program
    damage = resolveData_animDamage <$> resolveData :: [(Life, Life)]
    damagePa = sum $ fst <$> damage :: Life
    damagePb = sum $ snd <$> damage :: Life
  in
    (damagePa, damagePb)
