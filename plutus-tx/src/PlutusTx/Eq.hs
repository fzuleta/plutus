{-# OPTIONS_GHC -fno-omit-interface-pragmas #-}
module PlutusTx.Eq (Eq(..), (/=)) where

import           PlutusTx.Bool
import qualified PlutusTx.Builtins as Builtins

import           Prelude           hiding (Eq (..), not, (&&))

{- HLINT ignore -}

infix 4 ==, /=

-- Copied from the GHC definition
-- | The 'Eq' class defines equality ('==').
class Eq a where
    (==) :: a -> a -> Bool

    -- (/=) deliberately omitted, to make this a one-method class which has a
    -- simpler representation

{-# INLINABLE (/=) #-}
(/=) :: Eq a => a -> a -> Bool
x /= y = not (x == y)

instance Eq Integer where
    {-# INLINABLE (==) #-}
    (==) = Builtins.equalsInteger

instance Eq Builtins.BuiltinByteString where
    {-# INLINABLE (==) #-}
    (==) = Builtins.equalsByteString

instance Eq Builtins.BuiltinData where
    {-# INLINABLE (==) #-}
    (==) = Builtins.equalsData

instance Eq Builtins.BuiltinString where
    {-# INLINABLE (==) #-}
    (==) = Builtins.equalsString

instance Eq a => Eq [a] where
    {-# INLINABLE (==) #-}
    [] == []         = True
    (x:xs) == (y:ys) = x == y && xs == ys
    _ == _           = False

instance Eq Bool where
    {-# INLINABLE (==) #-}
    True == True   = True
    False == False = True
    _ == _         = False

instance Eq a => Eq (Maybe a) where
    {-# INLINABLE (==) #-}
    (Just a1) == (Just a2) = a1 == a2
    Nothing == Nothing     = True
    _ == _                 = False

instance (Eq a, Eq b) => Eq (Either a b) where
    {-# INLINABLE (==) #-}
    (Left a1) == (Left a2)   = a1 == a2
    (Right b1) == (Right b2) = b1 == b2
    _ == _                   = False

instance Eq () where
    {-# INLINABLE (==) #-}
    _ == _ = True

instance (Eq a, Eq b) => Eq (a, b) where
    {-# INLINABLE (==) #-}
    (a, b) == (a', b') = a == a' && b == b'

instance Eq Ordering where
    {-# INLINABLE (==) #-}
    EQ == EQ = True
    GT == GT = True
    LT == LT = True
    _ == _   = False
