{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE FlexibleContexts #-}
{-# OPTIONS_GHC -fno-warn-type-defaults #-}

-- | A JSON API which describes itself.

module Descriptive.JSON
  (-- * Combinators
   object
  ,key
  ,string
  ,integer
  -- * Description
  ,Doc(..)
  )
  where

import Descriptive

import Data.Aeson hiding (Value(Object),object)
import Data.Aeson.Types (Value,parseMaybe)
import Data.Bifunctor
import Data.Data
import Data.Monoid
import Data.Text (Text)

-- | Description of parseable things.
data Doc
  = Integer !Text
  | Text !Text
  | Object !Text
  | Key !Text
  deriving (Eq,Show,Typeable,Data)

-- | Consume an object.
object :: Text -- ^ Description of what the object is.
       -> Consumer Object Doc a -- ^ An object consumer.
       -> Consumer Value Doc a
object desc =
  wrap (\v d -> (Wrap doc (fst (d mempty)),v))
       (\v _ p ->
          case fromJSON v of
            Error{} -> (Failed (Unit doc),v)
            Success o ->
              (case p o of
                 (Failed e,_) -> Failed (Wrap doc e)
                 (Continued e,_) -> Failed (Wrap doc e)
                 (Succeeded a,_) -> Succeeded a
              ,toJSON o))
  where doc = Object desc

-- | Consume from object at the given key.
key :: Text -- ^ The key to lookup.
    -> Consumer Value Doc a -- ^ A value consumer of the object at the key.
    -> Consumer Object Doc a
key k =
  wrap (\o d ->
          first (Wrap doc)
                (second (const o)
                        (d (toJSON o))))
       (\o _ p ->
          case parseMaybe (const (o .: k))
                          () of
            Nothing -> (Failed (Unit doc),o)
            Just (v :: Value) ->
              first (bimap (Wrap doc) id)
                    (second (const o)
                            (p v)))
  where doc = Key k

-- | Consume a string.
string :: Text -- ^ Description of what the string is for.
       -> Consumer Value Doc Text
string doc =
  consumer (d,)
           (\s ->
              case fromJSON s of
                Error{} -> (Failed d,s)
                Success a -> (Succeeded a,s))
  where d = Unit (Text doc)

-- | Consume an integer.
integer :: Text -- ^ Description of what the integer is for.
        -> Consumer Value Doc Integer
integer doc =
  consumer (d,)
           (\s ->
              case fromJSON s of
                Error{} -> (Failed d,s)
                Success a -> (Succeeded a,s))
  where d = Unit (Integer doc)
