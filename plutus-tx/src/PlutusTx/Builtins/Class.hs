{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TypeFamilies             #-}
{-# OPTIONS_GHC -Wno-orphans #-}
{-# OPTIONS_GHC -fno-omit-interface-pragmas #-}
module PlutusTx.Builtins.Class where

import           Data.Kind

import           Data.ByteString            (ByteString)
import           PlutusTx.Builtins.Internal

import           Data.String                (IsString (..))

import qualified GHC.Magic                  as Magic

import           Prelude                    hiding (fst, head, null, snd, tail)

type BuiltinRep :: Type -> Type
{-|
The builtin Plutus Core type which represents the given type.

For example, Plutus Core has builtin booleans, but the Haskell 'Bool' type can also be
compiled into Plutus Core as a datatype. The 'FromBuiltin' and 'ToBuiltin' instances allows us to
convert between those in on-chain code.
-}
type family BuiltinRep a

{-|
A class witnessing the ability to convert from the builtin representation to the Haskell representation.
-}
class FromBuiltin a where
    fromBuiltin :: BuiltinRep a -> a

{-|
A class witnessing the ability to convert from the Haskell representation to the builtin representation.
-}
class ToBuiltin a where
    toBuiltin :: a -> BuiltinRep a

type instance BuiltinRep Integer = BuiltinInteger
instance FromBuiltin Integer where
    {-# INLINABLE fromBuiltin #-}
    fromBuiltin = id
instance ToBuiltin Integer where
    {-# INLINABLE toBuiltin #-}
    toBuiltin = id

type instance BuiltinRep Bool = BuiltinBool
instance FromBuiltin Bool where
    {-# INLINABLE fromBuiltin #-}
    fromBuiltin b = ifThenElse b True False
instance ToBuiltin Bool where
    {-# INLINABLE toBuiltin #-}
    toBuiltin b = if b then true else false

type instance BuiltinRep () = BuiltinUnit
instance FromBuiltin () where
    {-# INLINABLE fromBuiltin #-}
    fromBuiltin u = chooseUnit u ()
instance ToBuiltin () where
    {-# INLINABLE toBuiltin #-}
    toBuiltin x = case x of () -> unitval

type instance BuiltinRep ByteString = BuiltinByteString
instance FromBuiltin ByteString where
    {-# INLINABLE fromBuiltin #-}
    fromBuiltin = id
instance ToBuiltin ByteString where
    {-# INLINABLE toBuiltin #-}
    toBuiltin = id

type instance BuiltinRep Char = BuiltinChar
instance FromBuiltin Char where
    {-# INLINABLE fromBuiltin #-}
    fromBuiltin = id
instance ToBuiltin Char where
    {-# INLINABLE toBuiltin #-}
    toBuiltin = id

{- Note [noinline hack]
For some functions we have two conflicting desires:
- We want to have the unfolding available for the plugin.
- We don't want the function to *actually* get inlined before the plugin runs, since we rely
on being able to see the original function for some reason.

'INLINABLE' achieves the first, but may cause the function to be inlined too soon.

We can solve this at specific call sites by using the 'noinline' magic function from
GHC. This stops GHC from inlining it. As a bonus, it also won't be inlined if
that function is compiled later into the body of another function.

We do therefore need to handle 'noinline' in the plugin, as it itself does not have
an unfolding.
-}

-- We can't put this in `Builtins.hs`, since that force `O0` deliberately, which prevents
-- the unfoldings from going in. So we just stick it here. Fiddly.
instance IsString BuiltinString where
    -- Try and make sure the dictionary selector goes away, it's simpler to match on
    -- the application of 'stringToBuiltinString'
    {-# INLINE fromString #-}
    -- See Note [noinline hack]
    fromString = Magic.noinline stringToBuiltinString

{-# INLINABLE stringToBuiltinString #-}
stringToBuiltinString :: String -> BuiltinString
stringToBuiltinString = go
    where
        go []     = emptyString
        go (x:xs) = charToString x `appendString` go xs

type instance BuiltinRep BuiltinString = BuiltinString
instance FromBuiltin BuiltinString where
    {-# INLINABLE fromBuiltin #-}
    fromBuiltin = id
instance ToBuiltin BuiltinString where
    {-# INLINABLE toBuiltin #-}
    toBuiltin = id

{- Note [From/ToBuiltin instances for polymorphic builtin types]
For various technical reasons
(see Note [Representable built-in functions over polymorphic built-in types])
it's not always easy to provide polymorphic constructors for builtin types, but
we can usually provide destructors.

What this means in practice is that we can write a generic FromBuiltin instance
for pairs that makes use of polymorphic fst/snd builtins, but we can't write
a polymorphic ToBuiltin instance because we'd need a polymorphic version of (,).

Instead we write monomorphic instances corresponding to monomorphic constructor
builtins that we add for specific purposes.
-}

type instance BuiltinRep (a,b) = BuiltinPair (BuiltinRep a) (BuiltinRep b)
instance (FromBuiltin a, FromBuiltin b) => FromBuiltin (a,b) where
    {-# INLINABLE fromBuiltin #-}
    fromBuiltin p = (fromBuiltin $ fst p, fromBuiltin $ snd p)

type instance BuiltinRep [a] = BuiltinList (BuiltinRep a)
instance FromBuiltin a => FromBuiltin [a] where
    {-# INLINABLE fromBuiltin #-}
    fromBuiltin l = ifThenElse (null l) [] (fromBuiltin (head l):fromBuiltin (tail l))
