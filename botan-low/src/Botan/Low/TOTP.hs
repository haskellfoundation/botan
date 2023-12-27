{-|
Module      : Botan.Low.TOTP
Description : Time-based one time passwords
Copyright   : (c) Leo D, 2023
License     : BSD-3-Clause
Maintainer  : leo@apotheca.io
Stability   : experimental
Portability : POSIX

One time password schemes are a user authentication method that
relies on a fixed secret key which is used to derive a sequence
of short passwords, each of which is accepted only once. Commonly
this is used to implement two-factor authentication (2FA), where
the user authenticates using both a conventional password (or a
public key signature) and an OTP generated by a small device such
as a mobile phone.

Botan implements the HOTP and TOTP schemes from RFC 4226 and 6238.

Since the range of possible OTPs is quite small, applications must
rate limit OTP authentication attempts to some small number per 
second. Otherwise an attacker could quickly try all 1000000 6-digit
OTPs in a brief amount of time.

HOTP generates OTPs that are a short numeric sequence, between 6
and 8 digits (most applications use 6 digits), created using the
HMAC of a 64-bit counter value. If the counter ever repeats the
OTP will also repeat, thus both parties must assure the counter
only increments and is never repeated or decremented. Thus both
client and server must keep track of the next counter expected.

Anyone with access to the client-specific secret key can authenticate
as that client, so it should be treated with the same security
consideration as would be given to any other symmetric key or
plaintext password.

TOTP is based on the same algorithm as HOTP, but instead of a
counter a timestamp is used.
-}

module Botan.Low.TOTP where

import qualified Data.ByteString as ByteString

import Botan.Bindings.TOTP

import Botan.Low.Error
import Botan.Low.Make
import Botan.Low.Prelude
import Botan.Low.Remake

-- NOTE: RFC 6238

-- /**
-- * TOTP
-- */

newtype TOTP = MkTOTP { getTOTPForeignPtr :: ForeignPtr BotanTOTPStruct }

newTOTP      :: BotanTOTP -> IO TOTP
withTOTP     :: TOTP -> (BotanTOTP -> IO a) -> IO a
totpDestroy  :: TOTP -> IO ()
createTOTP   :: (Ptr BotanTOTP -> IO CInt) -> IO TOTP
(newTOTP, withTOTP, totpDestroy, createTOTP, _)
    = mkBindings
        MkBotanTOTP runBotanTOTP
        MkTOTP getTOTPForeignPtr
        botan_totp_destroy

type TOTPTimestep = Word64
type TOTPTimestamp = Word64
type TOTPCode = Word32

-- NOTE: Digits should be 6-8
totpInit :: ByteString -> ByteString -> Int -> TOTPTimestep -> IO TOTP
totpInit key algo digits timestep = asBytesLen key $ \ keyPtr keyLen -> do
    asCString algo $ \ algoPtr -> do
        createTOTP $ \ out -> botan_totp_init
            out
            (ConstPtr keyPtr)
            keyLen
            (ConstPtr algoPtr)
            (fromIntegral digits)
            (fromIntegral timestep)

-- WARNING: withFooInit-style limited lifetime functions moved to high-level botan
withTOTPInit :: ByteString -> ByteString -> Int -> TOTPTimestep -> (TOTP -> IO a) -> IO a
withTOTPInit = mkWithTemp4 totpInit totpDestroy

totpGenerate :: TOTP -> TOTPTimestamp -> IO TOTPCode
totpGenerate totp timestamp = withTOTP totp $ \ totpPtr -> do
    alloca $ \ outPtr -> do
        throwBotanIfNegative $ botan_totp_generate totpPtr outPtr timestamp
        peek outPtr

totpCheck :: TOTP -> TOTPCode -> TOTPTimestamp -> Int -> IO Bool
totpCheck totp code timestamp drift = withTOTP totp $ \ totpPtr -> do
    throwBotanCatchingSuccess $ botan_totp_check totpPtr code timestamp (fromIntegral drift)
