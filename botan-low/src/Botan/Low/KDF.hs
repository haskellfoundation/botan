{-|
Module      : Botan.Low.KDF
Description : Key Derivation Functions (KDF)
Copyright   : (c) Leo D, 2023
License     : BSD-3-Clause
Maintainer  : leo@apotheca.io
Stability   : experimental
Portability : POSIX

Key derivation functions are used to turn some amount of shared
secret material into uniform random keys suitable for use with
symmetric algorithms. An example of an input which is useful for
a KDF is a shared secret created using Diffie-Hellman key agreement.

Typically a KDF is also used with a salt and a label. The salt should
be some random information which is available to all of the parties
that would need to use the KDF; this could be performed by setting
the salt to some kind of session identifier, or by having one of the
parties generate a random salt and including it in a message.

The label is used to bind the KDF output to some specific context. For
instance if you were using the KDF to derive a specific key referred to
as the “message key” in the protocol description, you might use a label
of “FooProtocol v2 MessageKey”. This labeling ensures that if you
accidentally use the same input key and salt in some other context, you
still use different keys in the two contexts.
-}

module Botan.Low.KDF where

import qualified Data.ByteString as ByteString

import Botan.Bindings.KDF

import Botan.Low.Hash
import Botan.Low.MAC
import Botan.Low.Error
import Botan.Low.Make
import Botan.Low.Prelude

type KDFName = ByteString

-- NOTE: Untested. May be obsolete / deprecated.
--  No KDF algorithms are available on my Botan installation,
--  or at least I am getting NotImplementedException (-40) for all of them.
--  It is probable that there is a schema / format that I have not found yet.
-- SEE: Algos here: https://botan.randombit.net/doxygen/classBotan_1_1KDF.html
-- NOTE: Found algos in Z-botan, see end of file
kdfIO :: KDFName -> Int -> ByteString -> ByteString -> ByteString -> IO ByteString
kdfIO algo outLen secret salt label = allocBytes outLen $ \ outPtr -> do
    asCString algo $ \ algoPtr -> do
        asBytesLen secret $ \ secretPtr secretLen -> do
            asBytesLen salt $ \ saltPtr saltLen -> do
                asBytesLen label $ \ labelPtr labelLen -> do
                    throwBotanIfNegative_ $ botan_kdf
                        algoPtr
                        outPtr
                        (fromIntegral outLen)
                        secretPtr
                        secretLen
                        saltPtr
                        saltLen
                        labelPtr
                        labelLen

-- This works:
--  > kdf "KDF1(SHA-256)" 32 "Fee fi fo fum!" "English" "Bread"
-- Some have constraints on key length, eg MD5:
--  > kdf "KDF1(MD5)" 32 "Fee fi fo fum!" "English" "Bread"
--  *** Exception: BadParameterException (-32) ...
--  > kdf "KDF1(MD5)" 16 "Fee fi fo fum!" "English" "Bread"
--  "\234\176\202\212A\162\154]\238J\131aKL\142\197"