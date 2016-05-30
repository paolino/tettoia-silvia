{-# LANGUAGE CPP #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE RankNTypes #-}
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 702
{-# LANGUAGE Trustworthy #-}
{-# LANGUAGE DeriveGeneric #-}
#endif
{-# LANGUAGE DeriveDataTypeable #-}
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ < 708
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}
#endif
-----------------------------------------------------------------------------
-- |
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  portable
--
-- Operations on affine spaces.
-----------------------------------------------------------------------------
module Linear.Affine where

import Control.Applicative
import Control.DeepSeq
import Control.Monad (liftM)
import Control.Lens
import Data.Binary as Binary
import Data.Bytes.Serial
import Data.Complex (Complex)
import Data.Data
import Data.Distributive
import Data.Foldable as Foldable
import Data.Functor.Bind
import Data.Functor.Classes
import Data.Functor.Rep as Rep
import Data.HashMap.Lazy (HashMap)
import Data.Hashable
import Data.IntMap (IntMap)
import Data.Ix
import Data.Map (Map)
import Data.Serialize as Cereal
import Data.Vector (Vector)
import Foreign.Storable
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 702
import GHC.Generics (Generic)
#endif
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 706
import GHC.Generics (Generic1)
#endif
import Linear.Epsilon
import Linear.Metric
import Linear.Plucker
import Linear.Quaternion
import Linear.V
import Linear.V0
import Linear.V1
import Linear.V2
import Linear.V3
import Linear.V4
import Linear.Vector

#ifdef HLINT
{-# ANN module "HLint: ignore Unused LANGUAGE pragma" #-}
#endif

-- | An affine space is roughly a vector space in which we have
-- forgotten or at least pretend to have forgotten the origin.
--
-- > a .+^ (b .-. a)  =  b@
-- > (a .+^ u) .+^ v  =  a .+^ (u ^+^ v)@
-- > (a .-. b) ^+^ v  =  (a .+^ v) .-. q@
class Additive (Diff p) => Affine p where
  type Diff p :: * -> *

  infixl 6 .-.
  -- | Get the difference between two points as a vector offset.
  (.-.) :: Num a => p a -> p a -> Diff p a

  infixl 6 .+^
  -- | Add a vector offset to a point.
  (.+^) :: Num a => p a -> Diff p a -> p a

  infixl 6 .-^
  -- | Subtract a vector offset from a point.
  (.-^) :: Num a => p a -> Diff p a -> p a
  p .-^ v = p .+^ negated v
  {-# INLINE (.-^) #-}

-- | Compute the quadrance of the difference (the square of the distance)
qdA :: (Affine p, Foldable (Diff p), Num a) => p a -> p a -> a
qdA a b = Foldable.sum (fmap (join (*)) (a .-. b))
{-# INLINE qdA #-}

-- | Distance between two points in an affine space
distanceA :: (Floating a, Foldable (Diff p), Affine p) => p a -> p a -> a
distanceA a b = sqrt (qdA a b)
{-# INLINE distanceA #-}

#define ADDITIVEC(CTX,T) instance CTX => Affine T where type Diff T = T ; \
  (.-.) = (^-^) ; {-# INLINE (.-.) #-} ; (.+^) = (^+^) ; {-# INLINE (.+^) #-} ; \
  (.-^) = (^-^) ; {-# INLINE (.-^) #-}
#define ADDITIVE(T) ADDITIVEC((), T)

ADDITIVE([])
ADDITIVE(Complex)
ADDITIVE(ZipList)
ADDITIVE(Maybe)
ADDITIVE(IntMap)
ADDITIVE(Identity)
ADDITIVE(Vector)
ADDITIVE(V0)
ADDITIVE(V1)
ADDITIVE(V2)
ADDITIVE(V3)
ADDITIVE(V4)
ADDITIVE(Plucker)
ADDITIVE(Quaternion)
ADDITIVE(((->) b))
ADDITIVEC(Ord k, (Map k))
ADDITIVEC((Eq k, Hashable k), (HashMap k))
ADDITIVEC(Dim n, (V n))

-- | A handy wrapper to help distinguish points from vectors at the
-- type level
newtype Point f a = P (f a)
  deriving ( Eq, Ord, Show, Read, Monad, Functor, Applicative, Foldable
           , Eq1, Ord1, Show1, Read1
           , Traversable, Apply, Additive, Metric
           , Fractional , Num, Ix, Storable, Epsilon
           , Hashable
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 702
           , Generic
#endif
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 706
           , Generic1
#endif
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 708
           , Typeable, Data
#endif
           )

instance NFData (f a) => NFData (Point f a) where
  rnf (P x) = rnf x

instance Serial1 f => Serial1 (Point f) where
  serializeWith f (P p) = serializeWith f p
  deserializeWith m = P `liftM` deserializeWith m

instance Serial (f a) => Serial (Point f a) where
  serialize (P p) = serialize p
  deserialize = P `liftM` deserialize

instance Binary (f a) => Binary (Point f a) where
  put (P p) = Binary.put p
  get = P `liftM` Binary.get

instance Serialize (f a) => Serialize (Point f a) where
  put (P p) = Cereal.put p
  get = P `liftM` Cereal.get

#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ < 708
instance forall f. Typeable1 f => Typeable1 (Point f) where
  typeOf1 _ = mkTyConApp (mkTyCon3 "linear" "Linear.Affine" "Point") [] `mkAppTy`
              typeOf1 (undefined :: f a)

deriving instance (Data (f a), Typeable1 f, Typeable a) => Data (Point f a)
#endif

lensP :: Lens' (Point g a) (g a)
lensP afb (P a) = P <$> afb a
{-# INLINE lensP #-}

_Point :: Iso' (Point f a) (f a)
_Point = iso (\(P a) -> a) P
{-# INLINE _Point #-}

instance (t ~ Point g b) => Rewrapped (Point f a) t
instance Wrapped (Point f a) where
  type Unwrapped (Point f a) = f a
  _Wrapped' = _Point
  {-# INLINE _Wrapped' #-}

instance Bind f => Bind (Point f) where
  join (P m) = P $ join $ fmap (\(P m')->m') m

instance Distributive f => Distributive (Point f) where
  distribute = P . collect (\(P p) -> p)

instance Representable f => Representable (Point f) where
  type Rep (Point f) = Rep f
  tabulate f = P (tabulate f)
  {-# INLINE tabulate #-}
  index (P xs) = Rep.index xs
  {-# INLINE index #-}

type instance Index (Point f a) = Index (f a)
type instance IxValue (Point f a) = IxValue (f a)

instance Ixed (f a) => Ixed (Point f a) where
  ix l = lensP . ix l
  {-# INLINE ix #-}

instance Traversable f => Each (Point f a) (Point f b) a b where
  each = traverse
  {-# INLINE each #-}

instance R1 f => R1 (Point f) where
  _x = lensP . _x
  {-# INLINE _x #-}

instance R2 f => R2 (Point f) where
  _y = lensP . _y
  {-# INLINE _y #-}
  _xy = lensP . _xy
  {-# INLINE _xy #-}

instance R3 f => R3 (Point f) where
  _z = lensP . _z
  {-# INLINE _z #-}
  _xyz = lensP . _xyz
  {-# INLINE _xyz #-}

instance R4 f => R4 (Point f) where
  _w = lensP . _w
  {-# INLINE _w #-}
  _xyzw = lensP . _xyzw
  {-# INLINE _xyzw #-}

instance Additive f => Affine (Point f) where
  type Diff (Point f) = f
  P x .-. P y = x ^-^ y
  {-# INLINE (.-.) #-}
  P x .+^ v = P (x ^+^ v)
  {-# INLINE (.+^) #-}
  P x .-^ v = P (x ^-^ v)
  {-# INLINE (.-^) #-}

-- | Vector spaces have origins.
origin :: (Additive f, Num a) => Point f a
origin = P zero

-- | An isomorphism between points and vectors, given a reference
--   point.
relative :: (Additive f, Num a) => Point f a -> Iso' (Point f a) (f a)
relative p0 = iso (.-. p0) (p0 .+^)
{-# INLINE relative #-}

