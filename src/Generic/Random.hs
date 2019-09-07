-- | "GHC.Generics"-based 'Test.QuickCheck.arbitrary' generators.
--
-- = Basic usage
--
-- @
-- data Foo = A | B | C  -- some generic data type
--   deriving 'GHC.Generics.Generic'
-- @
--
-- Derive instances of 'Test.QuickCheck.Arbitrary'.
--
-- @
-- instance Arbitrary Foo where
--   arbitrary = 'genericArbitrary' 'uniform'  -- give a distribution of constructors
-- @
--
-- Or derive standalone generators (the fields must still be instances of
-- 'Test.QuickCheck.Arbitrary', or use custom generators).
--
-- @
-- genFoo :: Gen Foo
-- genFoo = 'genericArbitrary' 'uniform'
-- @
--
-- For more information:
--
-- - "Generic.Random.Tutorial"
-- - http://blog.poisson.chat/posts/2018-01-05-generic-random-tour.html

{-# LANGUAGE CPP #-}

module Generic.Random
  (
    -- * Arbitrary implementations

    -- | The suffixes for the variants have the following meanings:
    --
    -- - @U@: pick constructors with uniform distribution (equivalent to
    --   passing 'uniform' to the non-@U@ variant).
    -- - @Single@: restricted to types with a single constructor.
    -- - @G@: with custom generators.
    -- - @Rec@: decrease the size at every recursive call (ensuring termination
    --   for (most) recursive types).
    -- - @'@: automatic discovery of "base cases" when size reaches 0.
    genericArbitrary
  , genericArbitraryU
  , genericArbitrarySingle
  , genericArbitraryRec
  , genericArbitrary'
  , genericArbitraryU'

    -- ** With custom generators

    -- |
    -- === Note about incoherence
    --
    -- The custom generator feature relies on incoherent instances, which can
    -- lead to surprising behaviors for parameterized types.
    --
    -- ==== __Example__
    --
    -- For example, here is a pair type and a custom generator of @Int@ (always
    -- generating 0).
    --
    -- @
    -- data Pair a b = Pair a b
    --   deriving (Generic, Show)
    --
    -- customGen :: Gen Int
    -- customGen = pure 0
    -- @
    --
    -- The following two ways of defining a generator of @Pair Int Int@ are
    -- __not__ equivalent.
    --
    -- The first way is to use 'genericArbitrarySingleG' to define a
    -- @Gen (Pair a b)@ parameterized by types @a@ and @b@, and then
    -- specialize it to @Gen (Pair Int Int)@.
    --
    -- In this case, the @customGen@ will be ignored.
    --
    -- @
    -- genPair :: (Arbitrary a, Arbitrary b) => Gen (Pair a b)
    -- genPair = 'genericArbitrarySingleG' customGen
    --
    -- genPair' :: Gen (Pair Int Int)
    -- genPair' = genPair
    -- -- Will generate nonzero pairs
    -- @
    --
    -- The second way is to define @Gen (Pair Int Int)@ directly using
    -- 'genericArbitrarySingleG' (as if we inlined @genPair@ in @genPair'@
    -- above.
    --
    -- Then the @customGen@ will actually be used.
    --
    -- @
    -- genPair2 :: Gen (Pair Int Int)
    -- genPair2 = 'genericArbitrarySingleG' customGen
    -- -- Will only generate (Pair 0 0)
    -- @
    --
    -- In other words, the decision of whether to use a custom generator
    -- is done by comparing the type of the custom generator with the type of
    -- the field only in the context where 'genericArbitrarySingleG' is being
    -- used (or any other variant with a @G@ suffix).
    --
    -- In the first case above, those fields have types @a@ and @b@, which are
    -- not equal to @Int@ (or rather, there is no available evidence that they
    -- are equal to @Int@, even if they could be instantiated as @Int@ later).
    -- In the second case, they both actually have type @Int@.

  , genericArbitraryG
  , genericArbitraryUG
  , genericArbitrarySingleG
  , genericArbitraryRecG

    -- * Specifying finite distributions
  , Weights
  , W
  , (%)
  , uniform

    -- * Custom generators
  , (:+) (..)
#if __GLASGOW_HASKELL__ >= 800
  , FieldGen (..)
  , fieldGen
  , ConstrGen (..)
  , constrGen
#endif
  , Gen1 (..)
  , Gen1_ (..)

    -- * Helpful combinators
  , listOf'
  , listOf1'
  , vectorOf'

    -- * Base cases for recursive types
  , withBaseCase
  , BaseCase (..)

    -- * Full options
  , Options ()
  , genericArbitraryWith

    -- ** Size modifiers
  , Sizing (..)
  , setSized
  , setUnsized

    -- ** Custom generators
  , SetGens
  , setGenerators

    -- ** Common options
  , SizedOpts
  , sizedOpts
  , SizedOptsDef
  , sizedOptsDef
  , UnsizedOpts
  , unsizedOpts

    -- * Generic classes
  , GArbitrary
  , GUniformWeight

  ) where

import Generic.Random.Internal.BaseCase
import Generic.Random.Internal.Generic
