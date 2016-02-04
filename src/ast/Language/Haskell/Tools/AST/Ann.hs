{-# LANGUAGE FlexibleInstances
           , TemplateHaskell
           , DeriveDataTypeable
           #-}

-- | Parts of AST representation for keeping extra data
module Language.Haskell.Tools.AST.Ann where

import Data.Data
import Control.Lens
import SrcLoc
import Name
import Id

-- | An element of the AST keeping extra information.
data Ann elem annot
-- The type parameters are organized this way because we want the annotation type to
-- be more flexible, but the annotation is the first parameter because it eases 
-- pattern matching.
  = Ann { _annotation :: annot -- ^ The extra information for the AST part
        , _element    :: elem annot -- ^ The original AST part
        }
        
data NodeInfo sema src 
  = NodeInfo { _semanticInfo :: sema
             , _sourceInfo :: src
             }
  deriving (Show, Data)
             
makeLenses ''NodeInfo

data SemanticInfo 
  = NoSemanticInfo
  | NameInfo { _nameInfo :: Name }
  -- | ImplicitImports [ImportDecl]
  -- | ImplicitFieldUpdates [ImportDecl]
  
makeLenses ''SemanticInfo

type RangeInfo = NodeInfo () SrcSpan
type RangeWithName = NodeInfo SemanticInfo SrcSpan

class RangeAnnot annot where
  toRangeAnnot :: SrcSpan -> annot
  addSemanticInfo :: SemanticInfo -> annot -> annot
  extractRange :: annot -> SrcSpan
  
instance RangeAnnot RangeWithName where
  toRangeAnnot = NodeInfo NoSemanticInfo
  addSemanticInfo si = NodeInfo si . extractRange
  extractRange = view sourceInfo 
  
instance RangeAnnot RangeInfo where
  toRangeAnnot = NodeInfo ()
  addSemanticInfo si = id
  extractRange = view sourceInfo



-- | A list of AST elements
newtype AnnList e a = AnnList { _annList :: [Ann e a] }

-- | An optional AST element
newtype AnnMaybe e a = AnnMaybe { _annMaybe :: (Maybe (Ann e a)) }

-- | An empty list of AST elements
annNil :: AnnList e a
annNil = AnnList []

isAnnNothing :: AnnMaybe e a -> Bool
isAnnNothing (AnnMaybe Nothing) = True
isAnnNothing (AnnMaybe _) = False

-- | An existing AST element
annJust :: Ann e a -> AnnMaybe e a
annJust = AnnMaybe . Just

-- | A non-existing AST part
annNothing :: AnnMaybe e a
annNothing = AnnMaybe Nothing
