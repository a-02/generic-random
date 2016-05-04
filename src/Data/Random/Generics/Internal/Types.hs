{-# LANGUAGE RankNTypes, GADTs, ScopedTypeVariables, ImplicitParams #-}
{-# LANGUAGE TypeOperators, GeneralizedNewtypeDeriving #-}
module Data.Random.Generics.Internal.Types where

import Control.Applicative
import Control.Monad.Random
import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Trans.Maybe
import Data.Coerce
import Data.Data
import GHC.Stack ( CallStack, showCallStack )
import Test.QuickCheck

data SomeData m where
  SomeData :: Data a => m a -> SomeData m

type SomeData' = SomeData Proxy

-- | Dummy instance for debugging.
instance Show (SomeData m) where
  show _ = "SomeData"

data Alias m where
  Alias :: (Data a, Data b) => !(m a -> m b) -> Alias m

type AliasR m = Alias (RejectT m)

-- | Dummy instance for debugging.
instance Show (Alias m) where
  show _ = "Alias"

-- | Main constructor for 'Alias'.
alias :: (Monad m, Data a, Data b) => (a -> m b) -> Alias m
alias = Alias . (=<<)

-- | Main constructor for 'AliasR'.
aliasR :: (Monad m, Data a, Data b) => (a -> m b) -> AliasR m
aliasR = Alias . (=<<) . fmap lift

-- | > coerceAlias :: Alias m -> Alias (AMonadRandom m)
coerceAlias :: Coercible m n => Alias m -> Alias n
coerceAlias = coerce

-- | > coerceAliases :: [Alias m] -> [Alias (AMonadRandom m)]
coerceAliases :: Coercible m n => [Alias m] -> [Alias n]
coerceAliases = coerce

-- | > composeCast f g = f . g
composeCastM :: forall a b c d m
  . (?loc :: CallStack, Typeable b, Typeable c)
  => (m c -> d) -> (a -> m b) -> (a -> d)
composeCastM f g | Just Refl <- eqT :: Maybe (b :~: c) = f . g
composeCastM _ _ = castError ([] :: [b]) ([] :: [c])

castM :: forall a b m
  . (?loc :: CallStack, Typeable a, Typeable b)
  => m a -> m b
castM a | Just Refl <- eqT :: Maybe (a :~: b) = a
castM a = let x = castError a x in x

unSomeData :: (?loc :: CallStack, Typeable a) => SomeData m -> m a
unSomeData (SomeData a) = castM a

applyCast :: (Typeable a, Data b) => (m a -> m b) -> SomeData m -> SomeData m
applyCast f = SomeData . f . unSomeData

castError :: (?loc :: CallStack, Typeable a, Typeable b)
  => proxy a -> proxy' b -> c
castError a b = error $ unlines
  [ "Error trying to cast"
  , "  " ++ show (typeRep a)
  , "to"
  , "  " ++ show (typeRep b)
  , showCallStack ?loc
  ]

withProxy :: (?loc :: CallStack) => (a -> b) -> proxy a -> b
withProxy f _ =
  f (error $ "This should not be evaluated\n" ++ showCallStack ?loc)

reproxy :: proxy a -> Proxy a
reproxy _ = Proxy

proxyType :: m a -> proxy a -> m a
proxyType = const

someData' :: Data a => proxy a -> SomeData'
someData' = SomeData . reproxy

-- | Size as the number of constructors.
type Size = Int

newtype RejectT m a = RejectT
  { unRejectT :: ReaderT Size (StateT Size (MaybeT m)) a
  } deriving
  ( Functor, Applicative, Monad
  , Alternative, MonadPlus, MonadReader Size, MonadState Size
  )

instance MonadTrans RejectT where
  lift = RejectT . lift . lift . lift

-- | Set lower bound
runRejectT :: Monad m => (Size, Size) -> RejectT m a -> m a
runRejectT (minSize, maxSize) (RejectT m) = fix $ \go -> do
  x' <- runMaybeT (m `runReaderT` maxSize `runStateT` 0)
  case x' of
    Just (x, size) | size >= minSize -> return x
    _ -> go

newtype AMonadRandom m a = AMonadRandom
  { asMonadRandom :: m a
  } deriving (Functor, Applicative, Monad)

instance MonadTrans AMonadRandom where
  lift = AMonadRandom

-- ** Dictionaries

-- | @'MonadRandomLike' m@ defines basic components to build generators,
-- allowing the implementation to remain abstract over both the
-- 'Test.QuickCheck.Gen' type and 'MonadRandom' instances.
--
-- For the latter, the wrapper 'AMonadRandom' is provided to avoid
-- overlapping instances.
class Monad m => MonadRandomLike m where
  -- | Called for every constructor. Counter for ceiled rejection sampling.
  incr :: m ()
  incr = return ()

  -- | @doubleR@: generates values in @[0, upperBound)@.
  doubleR :: Double -> m Double

  -- | @integerR upperBound@: generates values in @[0, upperBound-1]@.
  integerR :: Integer -> m Integer

  -- | Default @Int@ generator.
  int :: m Int

  -- | Default @Double@ generator.
  double :: m Double

  -- | Default @Char@ generator.
  char :: m Char

instance MonadRandomLike Gen where
  doubleR x = choose (0, x)
  integerR x = choose (0, x-1)
  int = arbitrary
  double = arbitrary
  char = arbitrary

instance MonadRandomLike m => MonadRandomLike (RejectT m) where
  incr = do
    maxSize <- ask
    size <- get
    guard (size < maxSize)
    put (size + 1)
  doubleR = lift . doubleR
  integerR = lift . integerR
  int = lift int
  double = lift double
  char = lift char

instance MonadRandom m => MonadRandomLike (AMonadRandom m) where
  doubleR x = lift $ getRandomR (0, x)
  integerR x = lift $ getRandomR (0, x-1)
  int = lift getRandom
  double = lift getRandom
  char = lift getRandom
